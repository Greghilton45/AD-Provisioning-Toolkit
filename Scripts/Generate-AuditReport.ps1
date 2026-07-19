<#
.SYNOPSIS
    Generates a security/compliance audit report of all accounts in the store,
    the kind of report a sysadmin runs periodically for access reviews.

.DESCRIPTION
    Flags accounts that are enabled but have never had a password reset in
    90+ days, users not assigned to any group beyond Domain Users (possible
    orphaned accounts), and disabled accounts still holding group memberships
    (should be cleaned up). Outputs both console summary and a CSV report.

.PARAMETER UseRealAD
    Switch. Uses the real ActiveDirectory module instead of the simulator.

.EXAMPLE
    ./Generate-AuditReport.ps1
#>

[CmdletBinding()]
param(
    [switch]$UseRealAD
)

$root = Split-Path -Parent $PSScriptRoot
$reportPath = Join-Path $root "Reports\audit_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

if ($UseRealAD) {
    Import-Module ActiveDirectory -ErrorAction Stop
    $users = Get-ADUser -Filter * -Properties Enabled, PasswordLastSet, MemberOf, DistinguishedName
} else {
    Import-Module (Join-Path $root "Modules\ADSimulator.psm1") -Force
    $users = Get-SimADUser
}

$today = Get-Date
$findings = foreach ($u in $users) {
    $flags = @()

    $pwdAge = if ($u.PasswordLastSet) { ($today - [datetime]$u.PasswordLastSet).Days } else { $null }
    if ($u.Enabled -and $pwdAge -ne $null -and $pwdAge -gt 90) {
        $flags += "Password not rotated in $pwdAge days"
    }

    $groupCount = if ($u.MemberOf) { @($u.MemberOf).Count } else { 0 }
    if ($groupCount -le 1) {
        $flags += "No group memberships beyond default"
    }

    if (-not $u.Enabled -and $groupCount -gt 1) {
        $flags += "Disabled account still holds group memberships"
    }

    [PSCustomObject]@{
        SamAccountName = $u.SamAccountName
        Enabled        = $u.Enabled
        PasswordAgeDays = $pwdAge
        Groups         = ($u.MemberOf -join "; ")
        Findings       = ($flags -join " | ")
        RiskLevel      = if ($flags.Count -ge 2) { "High" } elseif ($flags.Count -eq 1) { "Medium" } else { "OK" }
    }
}

$findings | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "`nAudit Summary ($($findings.Count) accounts reviewed):" -ForegroundColor Cyan
$findings | Where-Object RiskLevel -ne "OK" | Format-Table SamAccountName, Enabled, RiskLevel, Findings -AutoSize
Write-Host "`nFull report: $reportPath" -ForegroundColor Green
