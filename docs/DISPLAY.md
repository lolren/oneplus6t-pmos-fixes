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

## Serialized brightness candidate (kernel r9)

The first display candidate adds a mutex around the Samsung S6E3FC2X01
backlight transaction. It snapshots the current MIPI-DSI mode flags while
holding that mutex, temporarily clears low-power mode for the brightness DCS
write, restores the flags even when the write fails, and initializes the lock
when the panel is probed. This specifically targets overlapping rapid slider
writes and prevents one update from observing another update's temporary DSI
flags. It does not claim to solve every DPU, DRM atomic, compositor or panel
fault.

The source patch is
`patches/linux-postmarketos-qcom-sdm845/0006-drm-panel-samsung-s6e3fc2x01-serialize-brightness.patch`.
Its SHA-512 is:

```text
c5fe9e034cfa358930dbe35bfa562d6556f46c58b692893113ea51a0909c5e78847dda433032412b46288640968d281ce9ad01c77e6711c641e9c3ffa2b7773e
```

The patch applies with no fuzz to the pinned sdm845 source and is embedded in
the pmaports integration patch. Reproduce the candidate package from the
documented pmaports base:

```sh
git checkout 875bddba6538818f2c3c9849e184f40688ad5140
git apply --check --whitespace=nowarn \
  /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
git apply --whitespace=nowarn \
  /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

The resulting `linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk` has SHA-256
`6049f30fb9ed0b5576f309720bfd75ea4d8faded4eadf10fc887d3d0a0aeb957` and is
signed by the repository's pinned development key. The retained r8 rollback
APK has SHA-256
`232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e`.

An opt-in signed stage is published in the
[display-r8-r9 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/display-r8-r9).
Extract it, keep `data/display-kernel-r8-r9.psv` and the public key from this
checkout, and run the simulation as the normal graphical login user:

```sh
pmos-manage-display-kernel \
  --stage /absolute/path/to/display-r8-r9 \
  --manifest /path/to/oneplus6t-pmos-fixes/data/display-kernel-r8-r9.psv \
  install
```

Review the evidence directory and the one-package `apk` operation. Only then
repeat with `--apply`; the manager never reboots. After a manual reboot,
collect a display report and test cold boot, lock/unlock, repeated brightness
sweeps, camera preview and suspend/resume. If the candidate fails, run the
same simulation with `rollback`, then repeat it with `--apply` and reboot
manually. Do not mix this kernel stage with a different manifest or copy its
kernel files directly into `/boot`.

Kernel r9 is retained as historical display-candidate evidence. It was
superseded on the reference phone by r10 below; neither package is claimed as a
brightness fix until the brightness-specific acceptance sequence passes.

## Installed r10 Venus recovery safety generation

Codec teardown diagnosis exposed a separate safety problem: after a Venus
firmware/session error, the level-triggered recovery interrupt could retrigger
continuously and let its FIFO IRQ thread starve unrelated storage work. Kernel
r10 retains all r9 display changes and adds
`0007-media-qcom-venus-bound-firmware-recovery-IRQ-work.patch`. Only while the
core is already in `sys_error`, it processes at most 32 message/debug packets
per IRQ pass and adds a bounded 10–20 ms delay before another asserted
interrupt can run. Normal encode IRQ handling is unchanged. This is damage
containment, not a substitute for fixing a userspace or firmware fault.

The exact artifacts are:

```text
kernel r10 APK: f5b3c8fa795b63718eebab9f2adbc0bee7545d2b147d5a0f3c1ae63c8176597e
kernel r8 rollback APK: 232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e
standalone 0007 patch: 0a3ad2342397670183dd3ddddd8d85dff306fa954bca0fdab26e9046c03faa36
pmaports integration: ce5daeadec278087ee0d334b0c9819c71022e9bb70f056adaf14762924c65d06
```

`data/kernel-r8-r10.psv` binds those APKs, the OnePlus 6T compatibility string
and the pinned public key. Simulate first, then explicitly apply only after the
evidence lists one kernel upgrade:

```sh
pmos-manage-display-kernel \
  --stage /absolute/path/to/kernel-r8-r10 \
  --manifest /path/to/oneplus6t-pmos-fixes/data/kernel-r8-r10.psv \
  install

pmos-manage-display-kernel \
  --stage /absolute/path/to/kernel-r8-r10 \
  --manifest /path/to/oneplus6t-pmos-fixes/data/kernel-r8-r10.psv \
  --apply install
```

The apply transaction runs the normal postmarketOS kernel package trigger,
which rebuilt and wrote the active `/boot/boot.img`. The manager does not call
fastboot, change slot metadata, touch bootloader/firmware or reboot. Retain the
r8 stage because rollback performs the same package-managed boot-image update
and also needs a manual reboot.

The reference phone booted r10 as `7.1.0-rc1-sdm845`. Three guarded Waydroid
Venus recording cycles then completed and cleanly tore down with no firmware
error, SMMU fault, IRQ storm, I/O pressure or blocked task. That accepts r10's
ordinary boot/camera compatibility; the error-containment branch correctly did
not run in a healthy encode. Repeated brightness sweeps, lock/unlock and
suspend/resume remain the separate display acceptance gate.
