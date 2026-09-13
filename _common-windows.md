# Common Windows playbook

Applies to Columbia, Odyssey and Sputnik. The per-box sheets carry only what differs.

bluesweep does not cover Windows — all of this is manual. Run PowerShell **as
Administrator**.

## 1. Rotate credentials first

Every account is `Passw0rd123!`.

```powershell
# Domain (Columbia)
Get-ADUser -Filter * -Properties PasswordLastSet,Enabled |
  Select-Object SamAccountName,Enabled,PasswordLastSet | Sort PasswordLastSet

$pw = Read-Host -AsSecureString "New password"
Get-ADUser -Filter 'Enabled -eq $true' |
  ForEach-Object { Set-ADAccountPassword $_ -Reset -NewPassword $pw }

# Local accounts (both hosts)
Get-LocalUser | Select Name,Enabled,LastLogon
Set-LocalUser -Name <user> -Password (Read-Host -AsSecureString)
```

Do **not** rotate service account passwords without updating the service — that is how you
take MSSQL or a scored app offline.

## 2. Find the accounts they added

```powershell
Get-LocalGroupMember Administrators
Get-ADGroupMember 'Domain Admins' | Select SamAccountName
Get-ADGroupMember 'Enterprise Admins','Schema Admins' -ErrorAction SilentlyContinue

# Recently created accounts
Get-ADUser -Filter * -Properties whenCreated |
  Where whenCreated -gt (Get-Date).AddDays(-1) | Select SamAccountName,whenCreated

# Accounts with no password required, or password never expires
Get-ADUser -Filter {PasswordNotRequired -eq $true -or PasswordNeverExpires -eq $true} |
  Select SamAccountName

# Kerberoastable: a user account with an SPN
Get-ADUser -Filter {ServicePrincipalName -like '*'} -Properties ServicePrincipalName |
  Select SamAccountName,ServicePrincipalName
```

Also check **AdminCount=1** accounts, which keep elevated ACLs even after being removed
from a privileged group:

```powershell
Get-ADUser -Filter {AdminCount -eq 1} -Properties AdminCount | Select SamAccountName
```

## 3. Persistence — where it actually hides

```powershell
# Scheduled tasks not from Microsoft
Get-ScheduledTask | Where { $_.TaskPath -notlike '\Microsoft\*' } |
  Select TaskName,TaskPath,State
Get-ScheduledTask | Where { $_.TaskPath -notlike '\Microsoft\*' } |
  ForEach-Object { $_.Actions | Select @{n='Task';e={$_.Execute}},Arguments }

# Services with a non-standard binary path, and unquoted paths
Get-CimInstance Win32_Service |
  Where { $_.PathName -notmatch 'C:\\Windows|C:\\Program Files' } |
  Select Name,State,StartMode,PathName

# Autoruns
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -EA SilentlyContinue

# WMI event subscriptions — fileless persistence, and almost never legitimate
Get-WmiObject -Namespace root\subscription -Class __EventFilter
Get-WmiObject -Namespace root\subscription -Class __EventConsumer
Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding

# Startup folders
Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp',
              "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -EA SilentlyContinue
```

## 5. Logging and monitoring

```powershell
# Live: new processes, new accounts, logons
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688} -MaxEvents 40 |
  Select TimeCreated,@{n='Cmd';e={$_.Properties[8].Value}}
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4720,4726,4728,4732,4756} -MaxEvents 40
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624,4625} -MaxEvents 40 |
  Select TimeCreated,@{n='User';e={$_.Properties[5].Value}},@{n='Src';e={$_.Properties[18].Value}}

netstat -anob | Select-String 'ESTABLISHED'
```

Event IDs worth memorising: **4688** process creation, **4720** account created, **4728/4732**
added to a group, **4624/4625** logon success/failure, **1102** audit log cleared (that one
is an incident by itself).

## 6. Firewall — single IPs only

```powershell
New-NetFirewallRule -DisplayName "Block <ip>" -Direction Inbound -RemoteAddress <ip> -Action Block
Get-NetFirewallProfile | Select Name,Enabled,DefaultInboundAction
```

## 7. Do not, in a six-hour game

- Reset `krbtgt` — correct in real DFIR, but two resets are required with a replication
  wait between them, and getting it wrong breaks authentication domain-wide.
- Demote or rebuild the DC.
- Change service account passwords without updating the services that use them.
- Disable a scored service to "harden" it. SMB and WinRM are scored on all three boxes.
