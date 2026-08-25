# Battery and power

Battery life must be measured on the actual phone before changing governors or
suspend policy. The OnePlus 6T kernel can advertise a setting without that
setting being stable across screen-off, modem reconnect and camera use.

## Read-only report

Run:

```sh
pmos-check-power --output /private/path/oneplus6t-power.txt
```

The report records:

- battery capacity, status, health, voltage/current and design/full charge
  values when the kernel exports them;
- CPU frequency governors, available policies, min/max/current frequency and
  energy-performance preference;
- supported suspend states and the current `mem_sleep` choice; and
- `power-profiles-daemon`/TLP state and any available power-profile setting.

It never writes sysfs, changes a governor, changes a charge limit, enables a
power profile or suspends the phone. It prints a suggestion to use
`powerprofilesctl set power-saver` only when the current profile is visibly
`performance`; apply that manually and measure battery drain before making it
the default.

## Acceptance sequence

After camera and modem recovery, collect reports at idle, during a 10-minute
camera preview and during a normal screen-off interval. Record capacity,
current draw, temperature and wake behavior. Then test, one at a time:

1. the existing balanced/default profile;
2. power-saver with Wi-Fi and mobile data each enabled separately; and
3. suspend/resume if `deep` is advertised in `mem_sleep`.

Reject any policy that causes a missed wake, modem reconnection failure,
camera reopen failure, unexpected thermal rise or materially worse idle drain.
No battery tweak is claimed as accepted until that sequence has completed on
the OnePlus 6T.
