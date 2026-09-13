# Sat — Ubuntu 22.04 `10.x.2.13`

**Scored: Modbus TCP (502).**
Start with [_common-linux.md](_common-linux.md), then the below.

Controlled **only** through the HMI/PLC on [Hubble](hubble-ubuntu-24.04.md).
**Availability is everything here and the protocol has no authentication.** Modbus TCP was
designed for trusted serial networks; there is no auth to turn on. Anyone who reaches 502
can issue writes.

Per the packet, the satellite is controlled **only** through the HMI/PLC on Hubble. So:

```sh
sudo ss -tlnp 'sport = :502'
```

1. Firewall 502 so it accepts **only Hubble's address** plus whatever the scoring engine
   uses. This is the entire defence.
2. Do not restart, reconfigure or "harden" the Modbus service. bluesweep reports it as
   `SRV006 INFO` with a `preserve_ics` fix tag precisely because breaking ICS availability
   is worse than the risk.
3. Watch it rather than changing it:
   ```sh
   sudo ss -tnp state established 'sport = :502'
   ```
   Any peer that is not Hubble is an incident, with the connection as your evidence.

```sh
sudo ufw allow from 10.x.2.11 to any port 502 proto tcp
sudo ufw default deny incoming; sudo ufw enable
```
