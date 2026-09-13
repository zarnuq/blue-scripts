# Columbia — Windows Server 2022 `10.x.1.10`

**Scored: LDAP/LDAPS (389/636), SMB (445), WinRM (5985/5986).**

The LDAP service means this is almost certainly the **domain controller** — the crown
jewels. Everything else on the internal subnet trusts it, so a compromise here is a
compromise everywhere.

Start with [_common-windows.md](_common-windows.md), then the below.

## Domain-specific account hunting

```powershell
Get-ADGroupMember 'Domain Admins' | Select SamAccountName
Get-ADGroupMember 'Enterprise Admins','Schema Admins' -ErrorAction SilentlyContinue

# Recently created accounts
Get-ADUser -Filter * -Properties whenCreated |
  Where whenCreated -gt (Get-Date).AddDays(-1) | Select SamAccountName,whenCreated

# No password required, or password never expires
Get-ADUser -Filter {PasswordNotRequired -eq $true -or PasswordNeverExpires -eq $true} |
  Select SamAccountName

# Kerberoastable: a user account carrying an SPN
Get-ADUser -Filter {ServicePrincipalName -like '*'} -Properties ServicePrincipalName |
  Select SamAccountName,ServicePrincipalName

# AdminCount=1 keeps elevated ACLs even after removal from a privileged group
Get-ADUser -Filter {AdminCount -eq 1} -Properties AdminCount | Select SamAccountName
```

## **GPO persistence (Columbia only)** — a modified GPO re-applies the backdoor to every host
every 90 minutes, so cleaning the endpoints alone will not hold:

```powershell
Get-GPO -All | Where ModificationTime -gt (Get-Date).AddDays(-1) |
  Select DisplayName,ModificationTime
Get-GPO -All | ForEach-Object { Get-GPOReport $_.Id -ReportType Xml } |
  Select-String -Pattern 'Scripts|ScheduledTask|cmd.exe|powershell'
```


## Service-specific

**LDAP/LDAPS (Columbia)** — require signing, and check for anonymous binds:

```powershell
Get-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$((Get-ADDomain).DistinguishedName)" `
  -Properties dSHeuristics
```


**SMB** — scored on both, so it stays on. Kill SMBv1 only:

```powershell
Get-SmbServerConfiguration | Select EnableSMB1Protocol,EnableSecuritySignature,RequireSecuritySignature
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
Get-SmbShare | Select Name,Path,Description        # remove shares you did not create
Get-SmbShare | Get-SmbShareAccess                  # look for Everyone / Full
```


**WinRM** — scored, so leave the listener. Restrict who can use it:

```powershell
winrm enumerate winrm/config/listener
Get-Item WSMan:\localhost\Service\AllowUnencrypted   # must be false
Get-PSSessionConfiguration | Select Name,Permission
```
