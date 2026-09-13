# Windows 10 — Sputnik `10.x.1.12`

**Scored: SMB (445), WinRM (5985/5986).**

A workstation on the internal subnet. Its value to the red team is not the box itself —
it is the **cached domain credentials** on it and the lateral path to
[Columbia](columbia-windows-server-2022.md) and [Odyssey](odyssey-windows-server-2022.md).

Start with [_common-windows.md](_common-windows.md), then the below.

## 1. Credentials — the real prize

```powershell
# Who has logged in and left credentials behind
Get-ChildItem C:\Users | Select Name,LastWriteTime
query user
Get-WmiObject Win32_NetworkLoginProfile | Select Name,LastLogon

# Cached logon count — 0 or 1 is safest for a workstation
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' `
  -Name CachedLogonsCount -EA SilentlyContinue

# Stored credentials in Credential Manager
cmdkey /list

# WDigest storing plaintext in memory (must be 0 or absent)
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' `
  -Name UseLogonCredential -EA SilentlyContinue
```

Set `UseLogonCredential` to 0 if present, and reduce `CachedLogonsCount`:

```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' `
  -Name UseLogonCredential -Value 0
```

Enable LSA protection so LSASS cannot be trivially read:

```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -Value 1
# takes effect on reboot - weigh that against uptime
```

## 2. Local accounts and lateral movement

```powershell
Get-LocalUser | Select Name,Enabled,LastLogon,PasswordLastSet
Get-LocalGroupMember Administrators
```

The classic lateral path is a **shared local Administrator password** across machines.
Make Sputnik's local admin password unique, and block local accounts from authenticating
over the network:

```powershell
# Denies network logon to local accounts - kills pass-the-hash to this box
New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
  -Name LocalAccountTokenFilterPolicy -Value 0 -PropertyType DWord -Force
```

Note: this can affect remote administration using local accounts. **WinRM is scored** — if
the check authenticates with a local account, confirm it still passes after this change.

## 3. Windows 10 specifics

```powershell
# Defender - do not disable it, and check nobody added an exclusion
Get-MpPreference | Select ExclusionPath,ExclusionProcess,ExclusionExtension
Get-MpComputerStatus | Select RealTimeProtectionEnabled,AntivirusEnabled
Get-MpThreatDetection | Select -First 20
```

An **exclusion path** nobody set is a strong indicator — it is how malware makes itself
invisible to Defender. Remove exclusions you did not create:

```powershell
Remove-MpPreference -ExclusionPath 'C:\path\they\added'
```

The packet says "no antivirus is allowed." Defender ships with the OS and is not something
you installed — do not *add* AV, but do not cripple the built-in either. Ask White Crew if
in doubt.

```powershell
# User-writable autorun locations specific to workstations
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

# Scheduled tasks running as the logged-in user
Get-ScheduledTask | Where { $_.Principal.UserId -notmatch 'SYSTEM|LOCAL|NETWORK' } |
  Select TaskName,TaskPath,@{n='User';e={$_.Principal.UserId}}
```

## 4. Persistence sweep

The common sheet's persistence sweep applies unchanged. Plus these workstation extras:

```powershell
# Office add-ins and templates, if Office is installed
Get-ChildItem "$env:APPDATA\Microsoft\Word\STARTUP",
              "$env:APPDATA\Microsoft\Excel\XLSTART" -EA SilentlyContinue

# Shortcut hijacks - a .lnk whose target was rewritten
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu" -Recurse -Filter *.lnk |
  ForEach-Object { $sh = New-Object -ComObject WScript.Shell
    $t = $sh.CreateShortcut($_.FullName); "$($_.Name) -> $($t.TargetPath) $($t.Arguments)" }
```

## 5. SMB and WinRM

Both scored — keep them running. Same hardening as the servers:

```powershell
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Get-SmbShare | Select Name,Path                 # remove shares you did not create
Get-SmbSession                                  # who is connected RIGHT NOW
Get-SmbOpenFile                                 # what they have open
```

`Get-SmbSession` is excellent incident-report evidence: it gives you the account and the
source IP of a live session.

## 6. Monitoring

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 30 |
  Select TimeCreated,@{n='User';e={$_.Properties[5].Value}},@{n='Src';e={$_.Properties[18].Value}},@{n='Type';e={$_.Properties[8].Value}}
```

Logon type **3** is network (SMB/WinRM), **10** is RDP. A type 3 or 10 from an address that
is not yours is your incident, and the event has the account and source IP already in it.
