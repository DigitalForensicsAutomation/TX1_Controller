Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------- TX1 DEVICES ----------------
$TX1Devices = @{
    "TX1-A" = "192.168.50.101"
    "TX1-B" = "192.168.50.102"
    "TX1-C" = "192.168.50.103"
}

# ---------------- GUI ----------------
$form = New-Object Windows.Forms.Form
$form.Text = "TX1 Acquisition Controller — Lab"
$form.Size = "460,460"

function Add-Label($text,$y){
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.Location = "10,$y"
    $l.Width = 140
    $form.Controls.Add($l)
}

function Add-Box($y){
    $b = New-Object Windows.Forms.TextBox
    $b.Location = "160,$y"
    $b.Width = 260
    $form.Controls.Add($b)
    return $b
}

Add-Label "Case ID:" 20
$caseBox = Add-Box 20

Add-Label "Exhibit #:" 60
$exhibitBox = Add-Box 60

Add-Label "Examiner:" 100
$examinerBox = Add-Box 100

Add-Label "Evidence Description:" 140
$descBox = Add-Box 140

Add-Label "Destination Root:" 180
$destBox = Add-Box 180
$destBox.Text = "D:\Evidence"

Add-Label "Select TX1:" 220
$deviceList = New-Object Windows.Forms.ComboBox
$deviceList.Location = "160,220"
$deviceList.Width = 260
$deviceList.Items.AddRange($TX1Devices.Keys)
$form.Controls.Add($deviceList)

$startBtn = New-Object Windows.Forms.Button
$startBtn.Text = "START ACQUISITION"
$startBtn.Location = "150,280"
$startBtn.Width = 180
$form.Controls.Add($startBtn)

# ---------------- FUNCTIONS ----------------

function Write-Log($path,$msg){
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time — $msg" | Out-File -Append $path
}

function Create-CaseStructure($root,$case){
    $base = Join-Path $root $case

    $folders = @(
        "01_Intake","02_Custody","03_Acquisition",
        "04_Images","05_Reports","06_Analysis",
        "07_Court","Photos"
    )

    foreach ($f in $folders){
        New-Item -ItemType Directory -Force -Path (Join-Path $base $f) | Out-Null
    }

    return $base
}

function Send-TX1Job($ip,$filename){
    # Example endpoint — adjust to TX1 firmware API
    $uri = "http://$ip/api/acquisition/start"

    $body = @{
        imageName = $filename
        format = "E01"
        hash = "MD5,SHA256"
        compression = "medium"
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType "application/json"
        return $true
    }
    catch {
        return $false
    }
}

function Monitor-TX1($ip,$log){
    $uri = "http://$ip/api/acquisition/status"

    do {
        Start-Sleep 10

        try {
            $status = Invoke-RestMethod -Uri $uri -Method GET
            Write-Log $log "TX1 Status: $($status.state)"
        }
        catch {
            Write-Log $log "Status check failed"
            return
        }

    } while ($status.state -ne "completed")

    Write-Log $log "Acquisition completed successfully"
}

# ---------------- MAIN EVENT ----------------

$startBtn.Add_Click({

    $case = $caseBox.Text.Trim()
    $exhibit = $exhibitBox.Text.Trim()
    $examiner = $examinerBox.Text.Trim()
    $desc = $descBox.Text.Trim()
    $destRoot = $destBox.Text.Trim()
    $deviceName = $deviceList.Text

    if (!$case -or !$exhibit -or !$examiner -or !$deviceName){
        [System.Windows.Forms.MessageBox]::Show("Required fields missing")
        return
    }

    $tx1IP = $TX1Devices[$deviceName]

    $date = Get-Date -Format "yyyyMMdd_HHmm"
    $filename = "${case}_EX${exhibit}_${date}.E01"

    # ----- Create Case Structure -----
    $caseFolder = Create-CaseStructure $destRoot $case

    $logPath = Join-Path $caseFolder "03_Acquisition\activity_log.txt"

    Write-Log $logPath "Acquisition initiated"
    Write-Log $logPath "Examiner: $examiner"
    Write-Log $logPath "Device: $deviceName ($tx1IP)"
    Write-Log $logPath "Filename: $filename"
    Write-Log $logPath "Description: $desc"

    # ----- Metadata -----
    $metadata = @{
        CaseID = $case
        Exhibit = $exhibit
        Examiner = $examiner
        Description = $desc
        TX1 = $deviceName
        TX1_IP = $tx1IP
        Filename = $filename
        Timestamp = Get-Date
    }

    $metaPath = Join-Path $caseFolder "01_Intake\metadata.json"
    $metadata | ConvertTo-Json -Depth 3 | Out-File $metaPath

    # ----- Dispatch Job -----
    Write-Log $logPath "Sending job to TX1"

    $result = Send-TX1Job $tx1IP $filename

    if (!$result){
        Write-Log $logPath "ERROR: Failed to start acquisition"
        [System.Windows.Forms.MessageBox]::Show("TX1 job dispatch FAILED")
        return
    }

    Write-Log $logPath "TX1 job started successfully"

    # ----- Monitor -----
    Monitor-TX1 $tx1IP $logPath

    Write-Log $logPath "Process complete"

    [System.Windows.Forms.MessageBox]::Show("Acquisition COMPLETE")
})

$form.ShowDialog()
