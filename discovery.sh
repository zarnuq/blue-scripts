#!/usr/bin/bash
echo "\n--- BEACON SEARCH ---\n" > sussy.log
sudo find / -name "*beacon*" 2>/dev/null >> sussy.log
echo "\n--- RED-TEAM SEARCH ---\n" >> sussy.log
sudo find / -name "*red-team*" 2>/dev/null >> sussy.log

