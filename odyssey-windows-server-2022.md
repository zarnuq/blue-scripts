# Odyssey — Windows Server 2022 `10.x.1.11`

**Scored: MSSQL (1433), SMB (445), WinRM (5985/5986).**

A member server, not the DC — but it holds the database, and MSSQL is the richest
persistence surface on the Windows side.

Start with [_common-windows.md](_common-windows.md), then the below.

## Service-specific

**MSSQL (Odyssey)** — scored remotely on 1433, so **do not bind it to localhost**.

```sql
SELECT name, is_disabled, type_desc FROM sys.server_principals WHERE type IN ('S','U','G');
SELECT * FROM sys.server_principals WHERE IS_SRVROLEMEMBER('sysadmin', name) = 1;
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell';          -- must be 0
EXEC sp_configure 'Ole Automation Procedures';
SELECT * FROM sys.assemblies WHERE is_user_defined = 1;   -- CLR backdoors
SELECT name, create_date FROM sys.triggers WHERE is_ms_shipped = 0;
```

Disable `xp_cmdshell` unless the application genuinely needs it, and check the `sa` account
is disabled or has a rotated password.


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
