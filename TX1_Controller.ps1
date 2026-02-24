# TX1 Acquisition Controller Starter
# Creates case folder and metadata file

param(
    [string]$CaseID,
    [string]$ExhibitID,
    [string]$Destination = "D:\Evidence"
)

$casePath = Join-Path $Destination $CaseID
New-Item -ItemType Directory -Force -Path $casePath

$meta = @{
    CaseID = $CaseID
    ExhibitID = $ExhibitID
    Timestamp = Get-Date
}

$meta | ConvertTo-Json | Out-File (Join-Path $casePath "metadata.json")

Write-Host "Case structure created at $casePath"
