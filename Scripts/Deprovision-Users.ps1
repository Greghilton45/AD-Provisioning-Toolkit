<#
.SYNOPSIS
    Offboards users: disables the account and logs the action, mirroring a
    real-world termination/offboarding checklist.

.DESCRIPTION
    Takes one or more SamAccountNames (or a CSV with a SamAccountName column)
    and disables each account rather than deleting it outright, which is
    standard practice so accounts can be audited before final removal.

.PARAMETER SamAccountNames
    One or more account names to disable, e.g. -SamAccountNames anguyen,bcoleman

.PARAMETER CsvPath
    Alternative to -SamAccountNames: a CSV file with a SamAccountName column.

.PARAMETER UseRealAD
    Switch. Uses the real ActiveDirectory module instead of the simulator.

.EXAMPLE
    ./Deprovision-Users.ps1 -SamAccountNames anguyen,bcoleman

.EXAMPLE
    ./Deprovision-Users.ps1 -CsvPath ../Data/departures.csv
#>

[CmdletBinding()]
param(
    [string[]]$SamAccountNames,
    [string]$CsvPath,
    [switch]$UseRealAD
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $root "Logs\deprovision_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

if ($UseRealAD) {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "Running in REAL AD mode" "WARN"
} else {
    Import-Module (Join-Path $root "Modules\ADSimulator.psm1") -Force
    Write-Log "Running in SIMULATION mode (no domain required)"
}

$targets = @()
if ($CsvPath) {
    if (-not (Test-Path $CsvPath)) { throw "CSV file not found: $CsvPath" }
    $targets = (Import-Csv -Path $CsvPath).SamAccountName
} elseif ($SamAccountNames) {
    $targets = $SamAccountNames
} else {
    throw "Provide either -SamAccountNames or -CsvPath."
}

foreach ($sam in $targets) {
    try {
        if ($UseRealAD) {
            Disable-ADAccount -Identity $sam
        } else {
            Disable-SimADAccount -Identity $sam
        }
        Write-Log "Disabled account '$sam'"
    }
    catch {
        Write-Log "FAILED to disable '$sam': $($_.Exception.Message)" "ERROR"
    }
}

Write-Log "Offboarding run complete for $($targets.Count) account(s)."
