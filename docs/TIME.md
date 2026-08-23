# Network time

## Failure mode

The tested phone initially booted with a system and RTC date in 1970. Cellular
IPv4 was already working, but DNSSEC treated current records as invalid and
HTTPS could not validate current certificates. This can look like a modem or
APN failure even though packet transport is healthy.

The modem reports no ModemManager network-time capability, so normal NTP is the
portable solution.

## Configuration

Enable `systemd-timesyncd` without changing the timezone:

```sh
sudo ./scripts/configure-time-sync
```

Optionally set the user's real timezone:

```sh
sudo ./scripts/configure-time-sync --timezone Europe/London
```

If the clock is too old for initial network services, seed it once from a
trusted, synchronized computer:

```sh
sudo ./scripts/configure-time-sync --epoch 1787485490
```

The script rejects implausibly old or non-numeric epochs. If setting the clock
fails after NTP has been paused, an exit trap re-enables NTP.

## Automatic behavior after boot

`systemd-timesyncd` is enabled at `sysinit.target`. Its service explicitly
disables DNSSEC validation only for NTP server hostname lookup, avoiding the
wrong-clock/DNSSEC cycle. It also maintains this timestamped state file:

```text
/var/lib/systemd/timesync/clock
```

At startup, systemd can use that timestamp as a clock floor before obtaining a
fresh NTP fix. The script does not write the phone's RTC or any boot partition.

Verify the result with:

```sh
timedatectl show -p NTP -p NTPSynchronized -p Timezone
systemctl is-enabled systemd-timesyncd.service
systemctl is-active systemd-timesyncd.service
```

Expected values are `NTP=yes`, `NTPSynchronized=yes`, `enabled` and `active`.
