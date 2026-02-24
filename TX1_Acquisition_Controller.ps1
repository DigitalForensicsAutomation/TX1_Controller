Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- TX1 Devices ---
$TX1Devices = @{
    "TX1-A" = "192.168.50.101"
    "TX1-B" = "192.168.50.102"
    "TX1-C" = "192.168.50.103"
}

# --- GUI ---
$form = New-Object Windows.Forms.Form
$form.Text = "TX1 Acquisition Controller"
$form.Size = "420,420"

function Add-Label($text,$y){
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.Location = "10,$y"
    $form.Controls.Add($l)
}

function Add-Box($y){
    $b = New-Object Windows.Forms.TextBox
    $b.Location = "150,$y"
    $b.Width = 230
    $form.Controls.Add($b)
    return $b
}

Add-Label "Case ID:" 20
$caseBox = Add-Box 20

Add-Label "Exhibit #:" 60
$exhibitBox = Add-Box 60

Add-Label "Examiner:" 100
$examinerBox = Add-Box 100

Add-Label "Evidence Desc:" 140
$descBox = Add-Box 140

Add-Label "Destination Root:" 180
$destBox = Add-Box 180
$destBox.Text = "D:\Evidence"

Add-Label "Select TX1:" 220
$deviceList = New-Object Windows.Forms.ComboBox
$deviceList.Location = "150,220"
$deviceList.Width = 230
$deviceList.Items.AddRange($TX1Devices.Keys)
$form.Controls.Add($deviceList)

$startBtn = New-Object Windows.Forms.Button
$startBtn.Text = "START ACQUISITION"
$startBtn.Location = "120,270"
$startBtn.Width = 160
$form.Controls.Add($startBtn)

# --- Acquisition Logic ---
$startBtn.Add_Click({

    $case = $caseBox.Text
    $exhibit = $exhibitBox.Text
    $examiner = $examinerBox.Text
    $desc = $descBox.Text
    $destRoot = $destBox.Text
    $deviceName = $deviceList.Text

    if (!$case -or !$exhibit -or !$deviceName) {
        [System.Windows.Forms.MessageBox]::Show("Missing required fields")
        return
    }

    $tx1IP = $TX1Devices[$deviceName]

    $date = Get-Date -Format "yyyyMMdd_HHmm"
    $filename = "${case}_EX${exhibit}_${date}.E01"

    $caseFolder = Join-Path $destRoot $case
    New-Item -ItemType Directory -Force -Path $caseFolder | Out-Null

    $metadata = @{
        CaseID = $case
        Exhibit = $exhibit
        Examiner = $examiner
        Description = $desc
        Device = $deviceName
        TX1_IP = $tx1IP
        Filename = $filename
        Timestamp = Get-Date
    }

    $metaPath = Join-Path $caseFolder "metadata.json"
    $metadata | ConvertTo-Json | Out-File $metaPath

    # --- TX1 Job Dispatch Placeholder ---
    Write-Host "Sending acquisition job to TX1 at $tx1IP"
    Write-Host "Filename: $filename"

    # Real deployment would POST to TX1 API here

    [System.Windows.Forms.MessageBox]::Show("Acquisition job dispatched")
})

$form.ShowDialog()
