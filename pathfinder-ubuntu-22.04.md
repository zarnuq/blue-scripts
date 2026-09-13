# Pathfinder — Ubuntu 22.04 `10.x.2.12`

**Scored: SSH (22), FTP (21), HTTP (80), MySQL (3306).**
Start with [_common-linux.md](_common-linux.md), then the below.

## MySQL — read this before touching the config

**The scoring engine connects to MySQL over the network.** The common advice
`bind-address = 127.0.0.1` (including in the old hardening sheet) will fail the check
instantly. Leave it bound, and secure it properly instead.

```sh
sudo mysql -e "SELECT user,host,plugin FROM mysql.user;"
sudo mysql -e "SELECT user,host FROM mysql.user WHERE authentication_string='' OR authentication_string IS NULL;"
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"           # anonymous users
sudo mysql -e "SELECT * FROM mysql.db WHERE Db='%';"            # wildcard grants
sudo mysql -e "SHOW GRANTS FOR 'root'@'%';" 2>/dev/null
sudo mysql -e "FLUSH PRIVILEGES;"
```

Rotate the application and root DB passwords, then **update the app config** that uses
them (`/var/www/*/config*.php`, `.env`) or you take down the scored HTTP service.

**The MySQL backdoor bluesweep cannot see.** It skips `SQL010` because it has no
credentials. Check these by hand — they are the classic persistence:

```sh
sudo mysql -e "SELECT * FROM mysql.func;"                       # UDF backdoors
sudo mysql -e "SHOW PLUGINS;" | grep -iv 'ACTIVE.*GPL'
sudo ls -la /usr/lib/mysql/plugin/                              # unexpected .so files
sudo mysql -e "SELECT @@plugin_dir, @@secure_file_priv;"        # empty secure_file_priv = file write
sudo mysql -e "SELECT * FROM mysql.user WHERE Super_priv='Y';"
```

An empty `secure_file_priv` lets `SELECT ... INTO OUTFILE` write files as the mysql user.
Set it to a directory.

## FTP

FTP is **scored**. Do not disable vsftpd, whatever the old sheet says.

```sh
sudo grep -vE '^\s*(#|$)' /etc/vsftpd.conf
```

Kill these if present: `anonymous_enable=YES`, `anon_upload_enable=YES`,
`anon_mkdir_write_enable=YES`, `chroot_local_user=NO`. An anonymous-writable FTP root
that overlaps the web root is instant RCE.

```sh
sudo systemctl restart vsftpd && sudo ss -tlnp 'sport = :21'    # confirm it came back
```

FTP data connections need conntrack. Load these **before** `kernel.modules_disabled=1`:

```sh
sudo modprobe nf_conntrack_ftp nf_nat_ftp
```

## HTTP

```sh
sudo ./bluesweep.sh --full --raw | grep -E 'WEB0|WEB1'          # webshell scan
sudo find /var/www -type f \( -name '*.php' -o -name '*.jsp' \) -mmin -120 -ls
sudo grep -rEl 'eval|base64_decode|system|passthru|assert|shell_exec' /var/www 2>/dev/null
```

Webshells hide in image extensions — bluesweep checks `.ico/.jpg/.png` for PHP. Also
check `.htaccess` and `.user.ini` for `auto_prepend_file`.

## Pathfinder firewall

```sh
sudo ufw allow 22/tcp; sudo ufw allow 21/tcp; sudo ufw allow 80/tcp; sudo ufw allow 3306/tcp
sudo ufw allow 30000:31000/tcp        # vsftpd passive range, match pasv_min/max_port
sudo ufw default deny incoming; sudo ufw enable
```
