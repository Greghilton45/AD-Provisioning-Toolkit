# AD Provisioning Toolkit

A PowerShell toolkit for bulk **onboarding, offboarding, and auditing** user accounts — the day-to-day workflow of a Systems/Network Administrator managing Active Directory.

Built to run **standalone on any machine** (macOS, Windows, Linux) via a built-in AD simulator, but written so it can be pointed at a **real Active Directory domain** with a single switch (`-UseRealAD`), using the official `ActiveDirectory` RSAT module.

## Why this project

In a real environment, admins routinely:
- Bulk-create accounts for new hires (from HR CSV exports)
- Assign users to the correct security groups
- Disable accounts on termination (never hard-delete immediately — audit first)
- Run periodic access/security audits (stale passwords, orphaned accounts)

This toolkit automates all four, with full logging for accountability and CSV reporting for compliance records.

## Project structure

```
AD-Provisioning-Toolkit/
├── Modules/
│   └── ADSimulator.psm1        # File-backed mock of ActiveDirectory cmdlets
├── Scripts/
│   ├── Provision-Users.ps1     # Bulk onboarding from CSV
│   ├── Deprovision-Users.ps1   # Offboarding / account disabling
│   └── Generate-AuditReport.ps1 # Security/compliance audit report
├── Data/
│   └── new_hires.csv           # Sample input data
├── Logs/                       # Timestamped run logs (auto-created)
└── Reports/                    # CSV output reports (auto-created)
```

## Requirements

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`) — works on macOS, Windows, and Linux
- For real AD mode only: Windows RSAT with the `ActiveDirectory` module and domain connectivity

## Install on macOS

```bash
brew install --cask powershell
pwsh
```

## Usage

**1. Bulk-provision new hires (simulation mode — no domain needed):**
```powershell
cd Scripts
./Provision-Users.ps1 -CsvPath ../Data/new_hires.csv
```

**2. Offboard departing employees:**
```powershell
./Deprovision-Users.ps1 -SamAccountNames anguyen,bcoleman
```

**3. Run a security/compliance audit:**
```powershell
./Generate-AuditReport.ps1
```

**4. Against a real Active Directory domain:**
```powershell
./Provision-Users.ps1 -CsvPath ../Data/new_hires.csv -UseRealAD -DefaultOU "OU=Employees,DC=contoso,DC=com"
```

Every run writes a timestamped log to `/Logs` and a CSV report to `/Reports`.

## Skills demonstrated

- Active Directory user lifecycle management (onboarding → offboarding)
- PowerShell scripting: parameters, error handling, logging, CSV I/O
- Security-mindful design (disable-before-delete, password age auditing, least-privilege group assignment)
- Writing code that's portable between a demo/sandbox environment and a real production domain

## Roadmap / next steps

- [ ] Add Pester unit tests
- [ ] Email notification on provisioning failures
- [ ] Integrate with a ticketing system (ServiceNow) to trigger provisioning from an approved request

---
*Built by Gregory Hilton — [LinkedIn](https://linkedin.com/in/greg-hilton-785a8225a)*
