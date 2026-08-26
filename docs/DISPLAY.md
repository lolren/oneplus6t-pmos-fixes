# Display and brightness diagnostics

The OnePlus 6T reference phone has reported horizontal static lines, corrupted
colours and an eventual display failure while the brightness slider is moved.
Android remains usable on the same hardware. This repository does not claim
that symptom is fixed yet: the failure can involve the panel, DSI transport,
DRM atomic commits, the DPU, the compositor or the backlight path, and a
blind kernel change could make the phone harder to recover.

## Read-only report

Run this as the graphical login user while the screen is awake:

```sh
./scripts/check-display --output /tmp/oneplus6t-display-report.txt
```

If the screen fails but SSH is still available, run the same command over SSH.
The command reads DRM connector state, active mode, backlight values, the
kernel command line and only display-related lines from `dmesg`. It refuses to
overwrite an existing report. It never moves the brightness slider, changes a
mode, writes a backlight value, alters power management or restarts the
compositor.

If `dmesg` is restricted, the report still collects sysfs evidence and records
`dmesg=unavailable`. A root invocation may provide the missing kernel log:

```sh
sudo ./scripts/check-display --output /tmp/oneplus6t-display-report-root.txt
```

Do not repeatedly exercise a known crash just to collect data. Capture one
baseline, reproduce the failure once with the screen awake, and collect a
second report as soon as the display is visibly corrupted. Keep both files
with their timestamps.

## Interpreting the report

- `display_state=connected-active` means the kernel exposes a connected
  connector and an active mode; it does not prove that every frame reaches the
  panel correctly.
- `brightness_control=available` means the normal backlight values are
  readable; it does not prove that rapid updates are safe.
- `Resource busy`, `atomic`, `dpu`, `encoder`, `panel`, `mipi` or
  `s6e3` lines are evidence to correlate with the failure timestamp, not an
  automatic diagnosis.
- Compare the connector mode and backlight values before and after the
  failure. A changed mode, missing connector, frozen brightness value or new
  DRM/panel error narrows the next investigation.

The fixture-backed test can be run on a development host:

```sh
sh tests/test-display-report.sh
```

## Current source boundary

The pinned OnePlus device definition already carries
 `console=ttyMSM0,115200` as a workaround for the SDM845 panel-initialisation
race described in [drm/msm issue
46](https://gitlab.freedesktop.org/drm/msm/-/issues/46). That workaround
addresses a boot-time panel race; it is not evidence of a brightness/static
fix and must not be removed casually.

After physical recovery, collect matching reports and kernel logs before
testing an isolated panel or DRM candidate. Any future kernel change must be
built as a versioned, rollbackable package and accepted only after cold boot,
screen lock/unlock, brightness sweeps, camera preview and suspend/resume all
remain stable.
