#!/bin/bash
# Creates exact mirror of important files in their original paths

BACKUP_ROOT="/tmp/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_ROOT"

echo "[+] Creating directory structure clone in $BACKUP_ROOT"
echo "[+] Started at: $(date)"

# Function to backup file preserving directory structure
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local dest="$BACKUP_ROOT$file"
        mkdir -p "$(dirname "$dest")"
        cp -p "$file" "$dest" 2>/dev/null
    fi
}

# Function to backup directory preserving structure
backup_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        local dest="$BACKUP_ROOT$dir"
        mkdir -p "$(dirname "$dest")"
        cp -rp "$dir" "$dest" 2>/dev/null
    fi
}

echo "[*] Cloning file structure..."

#=============================================================================
# /etc/ directory - most critical configs
#=============================================================================
backup_file "/etc/passwd"
backup_file "/etc/shadow"
backup_file "/etc/group"
backup_file "/etc/gshadow"
backup_file "/etc/sudoers"
backup_dir "/etc/sudoers.d"
backup_file "/etc/hosts"
backup_file "/etc/hosts.allow"
backup_file "/etc/hosts.deny"
backup_file "/etc/hostname"
backup_file "/etc/resolv.conf"
backup_file "/etc/nsswitch.conf"
backup_file "/etc/fstab"
backup_file "/etc/exports"
backup_file "/etc/crontab"
backup_file "/etc/anacrontab"
backup_file "/etc/login.defs"
backup_file "/etc/environment"
backup_file "/etc/profile"
backup_file "/etc/bash.bashrc"
backup_file "/etc/issue"
backup_file "/etc/issue.net"
backup_file "/etc/motd"
backup_file "/etc/rc.local"
backup_file "/etc/timezone"
backup_file "/etc/sysctl.conf"
backup_file "/etc/aliases"
backup_file "/etc/ftpusers"
backup_file "/etc/krb5.conf"
backup_dir "/etc/ssh"
backup_dir "/etc/pam.d"
backup_dir "/etc/security"
backup_dir "/etc/network"
backup_dir "/etc/netplan"
backup_dir "/etc/sysconfig"
backup_dir "/etc/ufw"
backup_dir "/etc/firewalld"
backup_dir "/etc/iptables"
backup_dir "/etc/apache2"
backup_dir "/etc/httpd"
backup_dir "/etc/nginx"
backup_dir "/etc/lighttpd"
backup_dir "/etc/mysql"
backup_dir "/etc/postgresql"
backup_dir "/etc/mongodb"
backup_dir "/etc/redis"
backup_dir "/etc/vsftpd"
backup_dir "/etc/proftpd"
backup_dir "/etc/postfix"
backup_dir "/etc/dovecot"
backup_dir "/etc/exim4"
backup_dir "/etc/bind"
backup_dir "/etc/dhcp"
backup_dir "/etc/samba"
backup_dir "/etc/ldap"
backup_dir "/etc/openldap"
backup_dir "/etc/cron.d"
backup_dir "/etc/cron.daily"
backup_dir "/etc/cron.hourly"
backup_dir "/etc/cron.weekly"
backup_dir "/etc/cron.monthly"
backup_dir "/etc/systemd"
backup_dir "/etc/init.d"
backup_dir "/etc/init"
backup_dir "/etc/default"
backup_dir "/etc/squid"
backup_dir "/etc/haproxy"
backup_dir "/etc/ssl"
backup_dir "/etc/pki"
backup_dir "/etc/letsencrypt"
backup_dir "/etc/apt"
backup_dir "/etc/yum.repos.d"
backup_dir "/etc/selinux"
backup_dir "/etc/apparmor.d"
backup_dir "/etc/docker"
backup_dir "/etc/profile.d"
backup_dir "/etc/sysctl.d"
backup_dir "/etc/modprobe.d"
backup_dir "/etc/grub.d"
backup_file "/etc/my.cnf"
backup_file "/etc/yum.conf"
backup_file "/etc/vsftpd.conf"
backup_file "/etc/proftpd.conf"
backup_file "/etc/named.conf"
backup_file "/etc/dnsmasq.conf"
backup_file "/etc/mongod.conf"

#=============================================================================
# /var/ directory - data and logs
#=============================================================================
backup_dir "/var/www"
backup_dir "/var/named"
backup_file "/var/lib/mysql/debian.cnf"
backup_dir "/var/spool/cron"

# Recent logs only (last modified)
if [ -f "/var/log/auth.log" ]; then backup_file "/var/log/auth.log"; fi
if [ -f "/var/log/secure" ]; then backup_file "/var/log/secure"; fi
if [ -f "/var/log/syslog" ]; then backup_file "/var/log/syslog"; fi
if [ -f "/var/log/messages" ]; then backup_file "/var/log/messages"; fi
if [ -f "/var/log/kern.log" ]; then backup_file "/var/log/kern.log"; fi

#=============================================================================
# /root/ directory
#=============================================================================
backup_file "/root/.bashrc"
backup_file "/root/.bash_profile"
backup_file "/root/.bash_history"
backup_file "/root/.profile"
backup_dir "/root/.ssh"
backup_dir "/root/.gnupg"

#=============================================================================
# /home/ directories
#=============================================================================
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        backup_file "$user_home/.bashrc"
        backup_file "$user_home/.bash_profile"
        backup_file "$user_home/.bash_history"
        backup_file "$user_home/.profile"
        backup_file "$user_home/.bash_logout"
        backup_dir "$user_home/.ssh"
        backup_dir "$user_home/.gnupg"
        backup_dir "$user_home/.config"
    fi
done

#=============================================================================
# /opt/ and /usr/local/ - applications
#=============================================================================
backup_dir "/opt"
backup_dir "/usr/share/nginx"
backup_dir "/usr/local/share/ca-certificates"

#=============================================================================
# /lib/systemd/ - system services
#=============================================================================
backup_dir "/lib/systemd/system"

#=============================================================================
# System state files (create in root of backup)
#=============================================================================
mkdir -p "$BACKUP_ROOT/SYSTEM_STATE/crontab"

iptables-save > "$BACKUP_ROOT/SYSTEM_STATE/iptables.rules" 2>/dev/null
ip6tables-save > "$BACKUP_ROOT/SYSTEM_STATE/ip6tables.rules" 2>/dev/null
ip addr show > "$BACKUP_ROOT/SYSTEM_STATE/ip_addresses.txt" 2>/dev/null
ip route show > "$BACKUP_ROOT/SYSTEM_STATE/routes.txt" 2>/dev/null
systemctl list-units --all > "$BACKUP_ROOT/SYSTEM_STATE/systemd_units.txt" 2>/dev/null
systemctl list-unit-files > "$BACKUP_ROOT/SYSTEM_STATE/systemd_unit_files.txt" 2>/dev/null
ps auxf > "$BACKUP_ROOT/SYSTEM_STATE/processes.txt" 2>/dev/null
netstat -tulpn > "$BACKUP_ROOT/SYSTEM_STATE/listening_ports.txt" 2>/dev/null
ss -tulpn > "$BACKUP_ROOT/SYSTEM_STATE/ss_listening.txt" 2>/dev/null
crontab -l > "$BACKUP_ROOT/SYSTEM_STATE/current_user_crontab.txt" 2>/dev/null
dpkg --get-selections > "$BACKUP_ROOT/SYSTEM_STATE/dpkg_packages.txt" 2>/dev/null
rpm -qa > "$BACKUP_ROOT/SYSTEM_STATE/rpm_packages.txt" 2>/dev/null
lsmod > "$BACKUP_ROOT/SYSTEM_STATE/loaded_modules.txt" 2>/dev/null
df -h > "$BACKUP_ROOT/SYSTEM_STATE/disk_usage.txt" 2>/dev/null
mount > "$BACKUP_ROOT/SYSTEM_STATE/mounts.txt" 2>/dev/null
uname -a > "$BACKUP_ROOT/SYSTEM_STATE/kernel_version.txt" 2>/dev/null
hostname > "$BACKUP_ROOT/SYSTEM_STATE/hostname.txt" 2>/dev/null

# All user crontabs
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -u $user -l > "$BACKUP_ROOT/SYSTEM_STATE/crontab/${user}.txt" 2>/dev/null
done
