# Wazuh SIEM — Ubuntu 24.04 (management subnet)

**No scored services. The red team will not touch this node.**
Start with [_common-linux.md](_common-linux.md), then the below.
**The red team will not touch this node. The packet forbids you from removing
`wazuh-agent` anywhere.** Treat it as the most valuable box you have.

```sh
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard
sudo /var/ossec/bin/agent_control -l                 # which agents are reporting
sudo tail -f /var/ossec/logs/alerts/alerts.json
```

## Use it for the incident report

The report needs processes, IPs, accounts and sessions. Wazuh has all four:

```sh
# Authentication events across every agent
sudo grep -E 'sshd|authentication' /var/ossec/logs/alerts/alerts.log | tail -50

# File integrity — what changed and when
sudo grep -i 'syscheck' /var/ossec/logs/alerts/alerts.log | tail -50
```

## Watch for agents going quiet

An agent that stops reporting is the attacker disabling your telemetry, and bluesweep
treats a previously-running agent that is now stopped as CRIT drift. Check every 15
minutes:

```sh
sudo /var/ossec/bin/agent_control -l | grep -i 'never\|disconnect'
```

On each monitored host, confirm the agent binary still matches its package — bluesweep
raises `PRV020` CRIT if a security agent's binary is owned by no package, which is what
agent replacement looks like:

```sh
dpkg -S "$(command -v wazuh-agentd 2>/dev/null || echo /var/ossec/bin/wazuh-agentd)"
```

Never stop it, never remove it, never "temporarily disable" it.
