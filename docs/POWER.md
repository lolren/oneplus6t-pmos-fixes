# Battery and power

Battery life must be measured on the actual phone before changing governors or
suspend policy. The OnePlus 6T kernel can advertise a setting without that
setting being stable across screen-off, modem reconnect and camera use.

The 2026-08-28 audit found the main immediate drain: the optional Waydroid
location bridge was rejecting Vanilla Android's default app-op response and
restarting every five seconds. It reached 381 restarts, with roughly 0.58 CPU
seconds consumed per failed attempt. Runtime r25 accepts that response,
rate-limits failures, restores the prior ModemManager GPS sources and refresh
rate, and remains disabled by default. Replacing GAPPS with the verified
Vanilla image also removes GMS, GSF and Play Store background work. With those
changes and no camera probe active, the connected phone measured about 96% CPU
idle while Waydroid was running or frozen.

The exact fixed helper package is published in the
[runtime-r25 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r25).

The kernel already exposes CPU idle/PSCI, Qualcomm RPMh power domains,
`schedutil`, generic PM sleep and runtime PM. It advertises only `s2idle` in
`mem_sleep`; that is normal on this ARM platform and this project does not
force a nonexistent `deep` mode. The latest fuel-gauge estimate was 3.192 Ah
full versus 3.640 Ah design, about 88% of design capacity, so battery wear also
sets a hard ceiling on runtime.

## Reversible battery suspend policy

The default graphical policy waited 900 seconds of battery inactivity before
suspend. Preview a five-minute policy as the login user:

```sh
pmos-configure-power --dry-run
```

After suspend/resume, modem reconnect and camera reopen have passed on the
installed kernel, apply it from the same graphical login session:

```sh
pmos-configure-power --apply
```

The helper changes only four per-user GNOME/Phosh settings: idle dimming,
low-battery power-saver selection, battery inactivity action and battery
inactivity timeout. The default is 300 seconds; `--timeout` accepts 60 through
3600 seconds. AC behavior, radios, CPU limits, charge limits, Waydroid images,
boot state and firmware are untouched. The exact previous values are stored
with mode 0600 under
`~/.local/state/oneplus6t-pmos-fixes/power-policy.tsv`. Restore them with:

```sh
pmos-configure-power --rollback
```

The phone's TuneD/PPD configuration already maps the balanced profile to
`balanced-battery` when unplugged, selecting `balance_power` while retaining
the normal balanced profile on external power. No additional governor cap is
applied without matched unplugged measurements.

On the reference phone, one unattended RTC-bounded `s2idle` cycle completed
with `success: 1` and every suspend failure counter at zero. USB networking,
Wi-Fi, cellular registration, the display and all camera nodes returned;
Waydroid restarted with three cameras and a post-resume surface probe passed.
The 300-second battery policy was then applied with the prior 900-second state
retained for rollback. Repeated cycles and unplugged idle drain remain open.

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

## Timed sampling

Use the sampler when a single report is not enough to compare idle, camera,
modem or screen-off drain:

```sh
pmos-measure-power --duration 600 --interval 10 \
  --output /private/path/oneplus6t-power-samples.txt
```

It reads the battery power-supply files once per interval and prints the
capacity, current, voltage, temperature and status for every sample, followed
by capacity delta, mean current and maximum temperature. `--duration 0` takes
one sample, which is useful for a quick check. The command refuses to
overwrite an existing output file and does not change a power, governor,
charge-limit or suspend setting. The fixture test covers the no-sleep,
single-sample path with `./tests/test-power-sampler.sh`.

USB power makes current readings unsuitable for a discharge baseline. Unplug
USB, leave the screen and radios in a recorded state, and run the sampler from
the phone itself. A ten-minute run can reveal a gross drain, but several
percent-hours of screen-off sampling are needed before claiming Android-like
standby.

## Acceptance sequence

After camera and modem recovery, collect reports at idle, during a 10-minute
camera preview and during a normal screen-off interval. Use
`pmos-measure-power` with the same interval and duration for each run, and
record capacity, current draw, temperature and wake behavior. Then test, one
at a time:

1. the existing balanced/default profile;
2. power-saver with Wi-Fi and mobile data each enabled separately; and
3. normal platform suspend/resume (`s2idle` on this kernel).

Reject any policy that causes a missed wake, modem reconnection failure,
camera reopen failure, unexpected thermal rise or materially worse idle drain.
No battery tweak is claimed as accepted until that sequence has completed on
the OnePlus 6T.

Android battery parity is not claimed. The proprietary Android 4.9 stack has
vendor firmware policy and device-specific power coordination that mainline
Linux may not reproduce exactly. This project will only call a change an
improvement when the same phone shows lower unplugged drain without missed
wakes, calls, messages, modem reconnects or camera regressions.
