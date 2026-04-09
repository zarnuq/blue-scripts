# Hardening Cheat Sheet for NCAE


# ufw fixes
sudo iptables-save > /tmp/iptables_backup.rules
sudo ufw reset
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw enable 

# Edit /etc/ssh/sshd_config
sudo nano /etc/ssh/sshd_config

## Key changes:
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2

sudo systemctl restart sshd


# Services
## List all running services
systemctl list-units --type=service --state=running

## Disable services you don't need
sudo systemctl stop telnet.service
sudo systemctl disable telnet.service
sudo systemctl stop vsftpd
sudo systemctl disable vsftpd

# Secure important files
sudo chmod 600 /etc/ssh/sshd_config
sudo chmod 600 /etc/shadow
sudo chmod 644 /etc/passwd
sudo chmod 600 /boot/grub/grub.cfg
find / -xdev -type f -perm -0002 -ls 2>/dev/null
sudo chmod o-w /tmp


# Cronjobs
## Check all cron jobs
sudo crontab -l
for user in $(cut -f1 -d: /etc/passwd); do 
    echo "=== $user ===" 
    sudo crontab -u $user -l 2>/dev/null
done

## Check system cron directories
ls -la /etc/cron.*
cat /etc/crontab

## Check systemd timers
systemctl list-timers

## Remove suspicious entries
sudo crontab -e

# Secure website files
- Apache - edit /etc/apache2/conf-enabled/security.conf
ServerTokens Prod
ServerSignature Off
TraceEnable Off

- Nginx - edit /etc/nginx/nginx.conf
server_tokens off;

- Disable directory listing
- Apache: Options -Indexes
- Nginx: autoindex off;

sudo systemctl restart apache2
sudo systemctl restart nginx


# MySQL/MariaDB
sudo mysql_secure_installation

## Remove anonymous users
mysql -u root -p -e "DELETE FROM mysql.user WHERE User='';"

## Remove remote root
mysql -u root -p -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

## Change bind address (listen only on localhost)
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
## Set: bind-address = 127.0.0.1

sudo systemctl restart mysql

# Logs
## Watch auth logs
sudo tail -f /var/log/auth.log

## Watch syslog
sudo tail -f /var/log/syslog

## Check failed login attempts
sudo grep "Failed password" /var/log/auth.log

## Check successful logins
sudo last
