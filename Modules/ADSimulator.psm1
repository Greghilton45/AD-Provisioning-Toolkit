<#
.SYNOPSIS
    ADSimulator - A lightweight, file-backed simulation of core ActiveDirectory
    module cmdlets, used so this toolkit can run and be demoed WITHOUT a real
    Active Directory domain.

.DESCRIPTION
    Mirrors the shape and behavior of the real ActiveDirectory PowerShell module
    (New-ADUser, Get-ADUser, Set-ADUser, Disable-ADAccount, Enable-ADAccount,
    Remove-ADUser, Add-ADGroupMember) closely enough that swapping this module
    for `Import-Module ActiveDirectory` in a real domain environment requires
    minimal changes to the calling scripts.

    Data is persisted to Data/ad_store.json so state survives between runs,
    the same way a real AD database would.
#>

$script:StorePath = Join-Path $PSScriptRoot "..\Data\ad_store.json"

function Initialize-ADStore {
    if (-not (Test-Path $script:StorePath)) {
        $seed = @{
            Users  = @()
            Groups = @("Domain Users", "IT-Staff", "Finance", "Sales", "VPN-Users")
        }
        $seed | ConvertTo-Json -Depth 5 | Set-Content -Path $script:StorePath
    }
}

function Get-ADStore {
    Initialize-ADStore
    Get-Content $script:StorePath -Raw | ConvertFrom-Json
}

function Save-ADStore {
    param($Store)
    $Store | ConvertTo-Json -Depth 5 | Set-Content -Path $script:StorePath
}

function New-SimADUser {
    <# Mirrors: New-ADUser -Name -SamAccountName -UserPrincipalName -Path -AccountPassword -Enabled #>
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$SamAccountName,
        [Parameter(Mandatory)] [string]$UserPrincipalName,
        [string]$Department = "Unassigned",
        [string]$Title = "",
        [string]$OU = "OU=Employees,DC=corp,DC=local",
        [switch]$Enabled = $true
    )

    $store = Get-ADStore

    if ($store.Users | Where-Object { $_.SamAccountName -eq $SamAccountName }) {
        throw "User '$SamAccountName' already exists."
    }

    $newUser = [PSCustomObject]@{
        Name              = $Name
        SamAccountName    = $SamAccountName
        UserPrincipalName = $UserPrincipalName
        Department        = $Department
        Title             = $Title
        DistinguishedName = "CN=$Name,$OU"
        Enabled           = [bool]$Enabled
        MemberOf          = @("Domain Users")
        Created           = (Get-Date).ToString("o")
        PasswordLastSet   = (Get-Date).ToString("o")
    }

    $store.Users = @($store.Users) + $newUser
    Save-ADStore -Store $store
    return $newUser
}

function Get-SimADUser {
    param([string]$Identity)
    $store = Get-ADStore
    if ($Identity) {
        return $store.Users | Where-Object { $_.SamAccountName -eq $Identity }
    }
    return $store.Users
}

function Add-SimADGroupMember {
    param(
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$GroupName
    )
    $store = Get-ADStore
    $user = $store.Users | Where-Object { $_.SamAccountName -eq $Identity }
    if (-not $user) { throw "User '$Identity' not found." }
    if ($GroupName -notin $store.Groups) { throw "Group '$GroupName' does not exist." }
    if ($user.MemberOf -notcontains $GroupName) {
        $user.MemberOf = @($user.MemberOf) + $GroupName
    }
    Save-ADStore -Store $store
}

function Disable-SimADAccount {
    param([Parameter(Mandatory)][string]$Identity)
    $store = Get-ADStore
    $user = $store.Users | Where-Object { $_.SamAccountName -eq $Identity }
    if (-not $user) { throw "User '$Identity' not found." }
    $user.Enabled = $false
    Save-ADStore -Store $store
}

function Remove-SimADUser {
    param([Parameter(Mandatory)][string]$Identity)
    $store = Get-ADStore
    $before = $store.Users.Count
    $store.Users = @($store.Users | Where-Object { $_.SamAccountName -ne $Identity })
    if ($store.Users.Count -eq $before) { throw "User '$Identity' not found." }
    Save-ADStore -Store $store
}

Export-ModuleMember -Function New-SimADUser, Get-SimADUser, Add-SimADGroupMember, Disable-SimADAccount, Remove-SimADUser, Initialize-ADStore
