# OnePlus 6T completion matrix

This document is the current audit of the requested OnePlus 6T
postmarketOS work. It separates source implementation, host validation and
physical-phone acceptance. A passing host test does not imply that a package
is installed or that the phone has passed the corresponding runtime test.

Audit date: 2026-08-27.

## Feature status

| Area | Implemented in the repositories | Host evidence | Remaining requirement |
| --- | --- | --- | --- |
| Daily-use setup | One command sequences the existing APN, network-time and audio-route helpers with dry-run/apply modes and independent rollback | Wrapper, shell syntax, dry-run/apply sequencing and package staging tests pass | Run the apply path in the phone's graphical user session and verify live bearer, synchronized clock and real modem-call routes |
| Mobile data | NetworkManager profile helper; provider database/GID-aware MVNO selection; UUID-scoped stale-bearer watchdog; managed rollback | Live SMARTY/3 UK LTE, Wi-Fi-off DNS/HTTPS and explicit network-side bearer-loss/watchdog recovery pass; watchdog fixtures cover health, cooldown, call deferral and ownership | Repeat after a cold boot and test an additional non-SMARTY SIM to broaden carrier acceptance |
| Network time | systemd network-time configuration and read-only check | Configuration and check scripts are tested | Verify synchronization after a real cold boot and cellular-only connection |
| Messages | Chatty/D-Bus/desktop activation diagnostic and fallback activation | Fixture-backed activation checks pass; prior touchscreen launch was recorded | Reconfirm on the recovered display |
| Audio routing | PipeWire-Pulse backend, WirePlumber hardware-monitor configuration and reversible built-in microphone policy | Native microphone capture is non-silent; Waydroid microphone recording and physical-speaker playback pass; backend/conflict and route-policy tests pass | Test earpiece, speakerphone and headset during a real modem call, then repeat after reboot |
| Display | Read-only DRM, connector and backlight diagnostic plus serialized Samsung panel-brightness candidate kernel r9 with r8 rollback | Display report fixtures pass; r9 AArch64 package compiles, applies to the pinned pmaports tree and verifies against the pinned APK key | Recover the phone, run the guarded simulation/apply path, then capture before/after reports and complete cold-boot, slider, lock/unlock, camera-preview and suspend/resume acceptance |
| Native camera sensors | IMX371/IMX376/IMX519 modes, Quad-Bayer handling, conservative AE, image controls and stable rear AF; r25 adds sustained-rise AF reference filtering; r26 adds standard manual shutter/gain controls | Full pMOS host suite, deterministic AF regression, clean AArch64 libcamera r26 build and signed runtime/IPA package verification pass; hardware acceptance pending | Install the r26 candidate and repeat live preview, still, focus, automatic/manual exposure, colour and suspend/resume tests |
| Native camera UI | Advanced Snapshot r14 source with tap-focus reticle, automatic/manual exposure, shutter/gain, exposure/colour/contrast/detail controls, 1x–4x pinch/slider zoom, latest-frame preview scheduling, save-failure feedback, guarded rear hardware-flash switch and opt-in software HDR | Pinned GTK build, formatting, 8 application tests, 5 HDR-helper tests, 9 Aperture tests, clippy, staged helper install and signed AArch64 r14 APK validation pass; phone acceptance pending | Verify visual preview latency, HDR output, saved images, manual exposure, playable video and rear LED restoration on the phone |
| Rear hardware flash | Bounded `pmos-camera-flash` helper for the OnePlus `white:flash`/`yellow:flash` channels; saves/restores brightness and handles interruption | Fixture test covers pulse, restoration, off and no-hardware paths | Run `pmos-camera-flash --status` and one rear still capture on the recovered phone; confirm no front-camera pulse |
| Android camera enumeration | Open Camera3 HAL for all three sensors, YUV/JPEG/private streams, AF/EV metadata and per-camera recording profiles | All three cameras pass single-output probes; CameraX sees the declared 480p/720p profiles | Repeat the complete three-camera probe on the reproducible r42 bundle and test front/auxiliary recording in real applications |
| Android camera performance/video | GPU software ISP with NV12 colour correction, native multi-output processing, Codec2 selection and Mesa software-codec policy | Clean 198-target ARMv7 build passes; installed r41 lets Aperture configure preview+encoder, receive a keyframe, mux H.264/AAC and finalize a playable 19-second clip | Benchmark r42 preview/record profiles, reduce the remaining sub-Android frame rate without regressing colour or multi-output correctness, and publish the bundle |
| Android camera image quality | Sensor-aware format/order handling, installed EGL NV12 red/blue correction and JPEG buffer validation | Live front-camera surface frame after r36 shows normal orange/teal channel relationships; JPEG/metadata fixtures and source checks pass | Compare a real face/colour chart, exposure, focus and back-camera sharpness against Android; vendor HDR/CCM/lens shading are not implemented |
| Waydroid apps | Guarded camera overlay installer, health preflight and separate GAPPS verifier | Installer, mount/I/O-pressure and GAPPS fixture tests pass | Clear the stale rootfs/physical recovery gate, then initialize or verify GAPPS only if desired |
| Location | Read-only ModemManager/GeoClue report; raw/NMEA, gpsd and formatted-ModemManager parser; reversible Android app-op/provider bridge tied to Waydroid lifecycle | Eight bridge tests pass; live service start/stop restores the original fused provider/app-op and rejects the modem's invalid indoor NMEA stream | Obtain a genuine outdoor GNSS fix and map-app acceptance; advertised Qualcomm A-GPS modes currently fail at the operation-mode indication and the bridge remains a mock provider rather than a GNSS HAL |
| NFC | Read-only controller/rfkill/device-node report, kernel-NCI `nfctool` discovery/poll path and libnfc fallback | NFC report fixtures cover both no-poll and `nfctool` polling selection | Install/enable `neard`, detect a real tag and validate a userspace reader |
| Battery life | Read-only power report and timed sampler with documented acceptance sequence | Power report and sampler tests pass | Measure idle, screen-on, camera and suspend drain on the recovered phone before changing governors or suspend policy |
| Update safety | Camera-critical package guard, immutable generation manifests, backups and retained rollback generations | Update-guard, generation-manager and VibeMarketOS tests pass | Re-run the health gate and complete a real-phone rollback/persistence test |

## Transport evidence

The host-side `scripts/check-device-transport` report is deliberately separate
from phone runtime acceptance. On 2026-08-27 it confirmed the OnePlus as
`ID_MODEL=OnePlus_6T` with a CDC-NCM interface, a working
`172.16.42.2/16` host link and ping to `172.16.42.1`; the latest bounded probe
completed TCP/22 and accepted the SSH banner. `fastboot devices` remains empty
and ADB shows only the separately attached Pixel. The NCM/SSH session is usable
for guarded userspace work, but it is not a bootloader or flashing session.

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
USB: CDC-NCM networking with working SSH
Fastboot: no device
OnePlus ADB: no device
SSH: TCP/22 usable
```

Until a physical recovery cycle restores Fastboot or ADB, do not flash a
partition, boot slot or firmware. The working SSH transport is sufficient for
guarded userspace and Waydroid procedures, which still require their own
health checks and live acceptance evidence.

The fixes package now includes `pmos-enable-ssh --apply`, an idempotent
systemd/OpenRC recovery helper that starts and persists `sshd` and verifies a
TCP/22 listener without changing firewall rules. It can be run from the
phone's local terminal or through the working SSH session.
