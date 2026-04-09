!#/bin/bash
read -sp "" P && sudo cat /etc/passwd | grep -v "nologin" | sed 's/:.*//' | awk -v p=$P '{print $1":"p}' | sudo chpasswd
