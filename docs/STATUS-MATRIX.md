# OnePlus 6T completion matrix

This document is the current audit of the requested OnePlus 6T
postmarketOS work. It separates source implementation, host validation and
physical-phone acceptance. A passing host test does not imply that a package
is installed or that the phone has passed the corresponding runtime test.

Audit date: 2026-08-26.

## Feature status

| Area | Implemented in the repositories | Host evidence | Remaining requirement |
| --- | --- | --- | --- |
| Mobile data | NetworkManager profile helper; provider database lookup; GID1-aware MVNO overlay; explicit APN fallback; managed rollback | APN selection and installer tests pass | Re-run on the recovered phone with the target SIM, then verify bearer, DNS and HTTPS |
| Network time | systemd network-time configuration and read-only check | Configuration and check scripts are tested | Verify synchronization after a real cold boot and cellular-only connection |
| Messages | Chatty/D-Bus/desktop activation diagnostic and fallback activation | Fixture-backed activation checks pass; prior touchscreen launch was recorded | Reconfirm on the recovered display |
| Audio routing | WirePlumber hardware-monitor configuration and reversible built-in microphone policy | Audio policy and helper checks pass | Test earpiece, speakerphone and headset during a real modem call |
| Display | Read-only DRM, connector, backlight and filtered-kernel diagnostic | Display report fixtures pass | Capture timestamped before/after reports; only then prepare and test a rollback-safe kernel/panel candidate for the static-line crash |
| Native camera sensors | IMX371/IMX376/IMX519 modes, Quad-Bayer handling, conservative AE, image controls and stable rear AF; r25 adds sustained-rise AF reference filtering | Full host suite and deterministic AF hysteresis regression pass; prior bounded all-sensor acceptance is recorded | Reinstall the r25 candidate and repeat live preview, still, focus, exposure, colour and suspend/resume tests |
| Native camera UI | Advanced Snapshot package with tap-focus reticle, exposure/colour/contrast/detail controls, 1x–4x pinch/slider zoom, latest-frame preview scheduling and r9 save-failure feedback | Clean GTK/Aperture tests, r9 AArch64 package validator and gesture trace pass | Verify visual preview latency, saved images and playable video on the phone |
| Android camera enumeration | Open Camera3 HAL for all three sensors, YUV/JPEG/private streams, AF and EV metadata | Probe source builds and host validators pass; the r35 baseline probe is recorded | Recover Waydroid, install the exact bundle and run the full three-camera probe |
| Android camera performance | GPU software-ISP baseline plus r37 RGB-private and r38 native-release-fence candidates; preview, surface and recording-template probe profiles | ARM build/signature checks and probe comparison tests pass | Compare `preview`, `preview-yuv`, `surface` and `record` on the same phone before selecting a new baseline |
| Android camera image quality | Sensor-aware format/order handling and JPEG buffer validation | JPEG/metadata fixtures and source checks pass | Compare front-camera colour/grid, exposure, focus and back-camera sharpness against Android; vendor HDR/CCM/lens shading are not implemented |
| Waydroid apps | Guarded camera overlay installer, health preflight and separate GAPPS verifier | Installer, mount/I/O-pressure and GAPPS fixture tests pass | Clear the stale rootfs/physical recovery gate, then initialize or verify GAPPS only if desired |
| Location | Read-only ModemManager/GeoClue report and dry-run-first Android test-provider bridge; raw NMEA, gpsd JSON and formatted ModemManager GPS parsing | Eight bridge tests, Python compilation and location report tests pass | Obtain a genuine native GNSS fix, validate GeoClue, then inject only accepted coordinates into Waydroid; the bridge is not a GNSS HAL |
| NFC | Read-only controller/rfkill/device-node report and explicit polling procedure | NFC report fixtures pass | Detect a real tag and validate a userspace reader |
| Battery life | Read-only power report and timed sampler with documented acceptance sequence | Power report and sampler tests pass | Measure idle, screen-on, camera and suspend drain on the recovered phone before changing governors or suspend policy |
| Update safety | Camera-critical package guard, immutable generation manifests, backups and retained rollback generations | Update-guard, generation-manager and VibeMarketOS tests pass | Re-run the health gate and complete a real-phone rollback/persistence test |

## Transport evidence

The host-side `scripts/check-device-transport` report is deliberately separate
from phone runtime acceptance. On 2026-08-26 it confirmed the OnePlus as
`ID_MODEL=OnePlus_6T` with a CDC-NCM interface, a working
`172.16.42.2/16` host link and ping to `172.16.42.1`; TCP/22 accepted a
connection but emitted no SSH banner. `fastboot devices` was empty and ADB
showed only the separately attached Pixel. This means the phone was not in USB
fastboot, and the NCM kernel path alone must not be treated as a usable SSH or
installation session.

## Reproducibility entry points

From a clean checkout of this repository:

```sh
make test
make install DESTDIR=/tmp/oneplus6t-pmos-fixes-stage PREFIX=/usr
```

The main procedures are:

- [CELLULAR.md](CELLULAR.md) — database-backed APN selection and rollback;
- [CAMERA_GENERATIONS.md](CAMERA_GENERATIONS.md) — signed native package
  generations and rollback;
- [WAYDROID.md](WAYDROID.md) — Camera3 build, overlay safety and probe
  profiles;
- [WAYDROID-GAPPS.md](WAYDROID-GAPPS.md) — separate optional Play Store
  procedure;
- [DISPLAY.md](DISPLAY.md), [LOCATION.md](LOCATION.md),
  [AUDIO.md](AUDIO.md), [NFC.md](NFC.md) and [POWER.md](POWER.md) — bounded
  diagnostics and physical acceptance sequences; and
- [ACCEPTANCE.md](ACCEPTANCE.md) — one unattended evidence-producing run
  covering the daily-use checks and optional camera/Messages/GAPPS gates; and
- [SAFETY.md](SAFETY.md) — operations that are deliberately refused.

## Current device gate

The last non-mutating host check found:

```text
172.16.42.1: ping responds
USB: CDC-NCM networking only
Fastboot: no device
OnePlus ADB: no device
SSH: TCP/22 accepts but no SSH banner
```

Until a physical recovery cycle restores a usable Fastboot, ADB or SSH
interface, do not install a new camera generation, modify a Waydroid overlay,
change the display driver, or claim runtime acceptance. The host-side source,
tests, package recipes and documentation can continue to be maintained, but
the phone-side gates above cannot be completed remotely through the current
interface.
