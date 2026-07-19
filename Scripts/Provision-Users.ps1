<#
.SYNOPSIS
    Bulk-provisions new user accounts from a CSV file, the same workflow used
    when onboarding a batch of new hires in a real Active Directory environment.

.DESCRIPTION
    Reads a CSV of new hires, creates an AD user for each row, assigns them to
    the correct security group, logs every action with a timestamp, and writes
    a summary report to /Reports.

    By default this runs against the built-in ADSimulator so it can be demoed
    on any machine (no domain required). Pass -UseRealAD to run the exact same
    logic against a real Active Directory domain using the official
    ActiveDirectory PowerShell module (RSAT).

.PARAMETER CsvPath
    Path to the input CSV. Must contain: FullName, SamAccountName, Department,
    Title, Group

.PARAMETER UseRealAD
    Switch. If set, uses the real ActiveDirectory module cmdlets instead of
    the simulator. Requires RSAT / the ActiveDirectory module and domain
    connectivity.

.PARAMETER DefaultOU
    Distinguished Name of the OU new users should land in (real AD mode only).

.EXAMPLE
    ./Provision-Users.ps1 -CsvPath ../Data/new_hires.csv

.EXAMPLE
    ./Provision-Users.ps1 -CsvPath ../Data/new_hires.csv -UseRealAD -DefaultOU "OU=Employees,DC=contoso,DC=com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [switch]$UseRealAD,

    [string]$DefaultOU = "OU=Employees,DC=corp,DC=local",

    [string]$UpnSuffix = "corp.local"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $root "Logs\provision_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$reportPath = Join-Path $root "Reports\provision_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

if ($UseRealAD) {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Running in REAL AD mode against domain $(($env:USERDNSDOMAIN))" "WARN"
} else {
    Import-Module (Join-Path $root "Modules\ADSimulator.psm1") -Force
    Write-Log "Running in SIMULATION mode (no domain required)"
}

if (-not (Test-Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$hires = Import-Csv -Path $CsvPath
Write-Log "Loaded $($hires.Count) record(s) from $CsvPath"

$results = foreach ($hire in $hires) {
    $status = "Success"
    $errorMsg = ""

    try {
        $upn = "$($hire.SamAccountName)@$UpnSuffix"

        if ($UseRealAD) {
            $securePwd = ConvertTo-SecureString ("Temp!" + (Get-Random -Minimum 10000 -Maximum 99999)) -AsPlainText -Force
            New-ADUser -Name $hire.FullName `
                       -SamAccountName $hire.SamAccountName `
                       -UserPrincipalName $upn `
                       -Path $DefaultOU `
                       -Department $hire.Department `
                       -Title $hire.Title `
                       -AccountPassword $securePwd `
                       -ChangePasswordAtLogon $true `
                       -Enabled $true
            Add-ADGroupMember -Identity $hire.Group -Members $hire.SamAccountName
        } else {
            New-SimADUser -Name $hire.FullName `
                           -SamAccountName $hire.SamAccountName `
                           -UserPrincipalName $upn `
                           -Department $hire.Department `
                           -Title $hire.Title `
                           -OU $DefaultOU | Out-Null
            Add-SimADGroupMember -Identity $hire.SamAccountName -GroupName $hire.Group
        }

        Write-Log "Provisioned '$($hire.SamAccountName)' ($($hire.FullName)) -> group '$($hire.Group)'"
    }
    catch {
        $status = "Failed"
        $errorMsg = $_.Exception.Message
        Write-Log "FAILED to provision '$($hire.SamAccountName)': $errorMsg" "ERROR"
    }

    [PSCustomObject]@{
        FullName       = $hire.FullName
        SamAccountName = $hire.SamAccountName
        Department     = $hire.Department
        Group          = $hire.Group
        Status         = $status
        Error          = $errorMsg
        Timestamp      = (Get-Date -Format "o")
    }
}

$results | Export-Csv -Path $reportPath -NoTypeInformation
$successCount = ($results | Where-Object Status -eq "Success").Count
$failCount = ($results | Where-Object Status -eq "Failed").Count

Write-Log "Provisioning complete: $successCount succeeded, $failCount failed."
Write-Log "Report written to $reportPath"

Write-Host "`nSummary:" -ForegroundColor Cyan
$results | Format-Table FullName, SamAccountName, Group, Status -AutoSize
