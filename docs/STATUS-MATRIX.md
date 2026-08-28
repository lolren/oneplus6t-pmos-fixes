# OnePlus 6T completion matrix

This document is the current audit of the requested OnePlus 6T
postmarketOS work. It separates source implementation, host validation and
physical-phone acceptance. A passing host test does not imply that a package
is installed or that the phone has passed the corresponding runtime test.

Audit date: 2026-08-28.

## Feature status

| Area | Implemented in the repositories | Host evidence | Remaining requirement |
| --- | --- | --- | --- |
| Daily-use setup | One command sequences the existing APN, network-time and audio-route helpers with dry-run/apply modes and independent rollback | Wrapper, shell syntax, dry-run/apply sequencing and package staging tests pass | Run the apply path in the phone's graphical user session and verify live bearer, synchronized clock and real modem-call routes |
| Mobile data | NetworkManager profile helper; provider database/GID-aware MVNO selection; UUID-scoped stale-bearer watchdog; managed rollback; guarded native/Waydroid cellular-only acceptance command with exact device-bound Wi-Fi restoration | Cold-boot r23 and the newly reinserted SMARTY SIM both register and connect through database-selected `mob.asm.net`; cellular-only default route, DNS, HTTPS and Wi-Fi restoration pass. Earlier Waydroid NAT and explicit bearer-loss/watchdog recovery also pass | Repeat the packaged test with the current running Waydroid session and test an additional non-SMARTY SIM to broaden carrier acceptance |
| Network time | systemd network-time configuration and read-only check | Configuration/fixture tests pass; after the real cold boot `systemd-timesyncd` is active, `NTPSynchronized=yes`, Europe/London is selected and cellular HTTPS succeeds | Recheck only after a base-system time-service change |
| Messages | Chatty/D-Bus/desktop activation diagnostic and fallback activation | Fixture-backed activation checks pass; prior touchscreen launch was recorded | Reconfirm on the recovered display |
| Audio routing | PipeWire-Pulse backend, WirePlumber hardware-monitor configuration and reversible built-in microphone policy | Native microphone capture is non-silent; Waydroid microphone recording and physical-speaker playback pass; backend/conflict and route-policy tests pass | Test earpiece, speakerphone and headset during a real modem call, then repeat after reboot |
| Display/kernel safety | Read-only DRM/backlight diagnostic; serialized Samsung brightness writes; r10 bounds Venus recovery IRQ work only during firmware error; r8 rollback manifest | r10 is installed; ordinary main/front recordings pass. Both auxiliary stop orders cause a delayed IRQ spike; watchdog/emergency reboot recovery completed with clean filesystems, zero pressure and zero D-state tasks | Do not deliberately exercise auxiliary Venus encoding again; strengthen recovery containment separately and complete brightness slider/lock/suspend acceptance |
| Native camera sensors | IMX371/IMX376/IMX519 modes, Quad-Bayer handling, conservative AE, image controls and stable rear AF; r25 adds sustained-rise AF reference filtering; r26 adds standard manual shutter/gain controls | Full pMOS host suite, deterministic AF regression, clean AArch64 libcamera r26 build and signed runtime/IPA package verification pass; hardware acceptance pending | Install the r26 candidate and repeat live preview, still, focus, automatic/manual exposure, colour and suspend/resume tests |
| Native camera UI | Advanced Snapshot r15 source with tap-focus reticle, automatic/manual exposure, shutter/gain, exposure/colour/contrast/detail controls, 1x–4x pinch/slider zoom, latest-frame preview scheduling, save-failure feedback, guarded rear hardware-flash switch and opt-in software HDR with bounded handheld translation alignment | Pinned GTK build, formatting, 27 workspace tests, strict clippy, five Meson release gates, staged install and independently validated signed AArch64 r15 APKs pass; phone acceptance pending | Verify visual preview latency, aligned HDR output, saved images, manual exposure, playable video and rear LED restoration on the phone |
| Rear hardware flash | Bounded `pmos-camera-flash` helper for the OnePlus `white:flash`/`yellow:flash` channels; saves/restores brightness and handles interruption | Fixture test covers pulse, restoration, off and no-hardware paths | Run `pmos-camera-flash --status` and one rear still capture on the recovered phone; confirm no front-camera pulse |
| Android camera enumeration | Open Camera3 HAL for all three sensors, YUV/JPEG/private streams, AF/EV metadata, mixed RGB/NV12 coalescing, private-preview cap, source-fence-safe post-processing and guarded main/front recording profiles | Installed r51 retains the exact accepted r50 runtime and passes all three previews; r50's full probe decoded every JPEG with zero repeated row discontinuities. Android reports profiles for IDs 0/1 and none for unsafe auxiliary ID 2 | Retain the exact r50/r51 regressions; keep auxiliary recording unadvertised until a non-Venus path or kernel/Codec2 fix passes teardown |
| Android camera performance/video | GPU software ISP with NV12 colour correction, coalesced multi-output processing, ranked Venus Codec2, MMAP compressed output, exact single-plane NV12 layout/lifetime and metadata-only temporary stride discovery | Main rear H.264/AAC fully decodes at 11.78 fps; a dedicated safe control reaches 29.78 fps. Front r50 video fully decodes at 24.77 fps with AAC. Both auxiliary teardown orders trigger the same Venus IRQ storm, so installed r51 removes its profile and the probe hard-refuses it | Investigate an explicit software encoder or kernel/Codec2 fix; continue long capture, app switching and suspend/resume only on main/front |
| Android camera image quality | Sensor-aware format/order handling, EGL NV12 red/blue correction, JPEG decoding/row-integrity checks and source-fence synchronization | Exact r50 all-camera JPEGs have zero repeated row discontinuities; private front video has normal colour without purple or green/static lines | Compare a real face/colour chart, exposure, focus and back-camera sharpness against Android; vendor HDR/CCM/lens shading are not implemented |
| Waydroid apps | Guarded camera/Codec2 overlay installers, health preflight, streamed Camera2 probe installation and separate GAPPS verifier | r51 safety generation is installed and accepted; all three previews pass, only IDs 0/1 expose recording profiles, and orderly shutdown leaves zero mounts, D-state tasks and current I/O pressure. Host installer/build/probe/GAPPS tests pass | Validate Play Store lifecycle without auxiliary hardware encoding |
| Location | Read-only ModemManager/GeoClue report; raw/NMEA, gpsd and formatted-ModemManager parser; reversible Android app-op/provider bridge tied to Waydroid lifecycle | Eight bridge tests pass; live service lifecycle restores the fused provider/app-op; current indoor NMEA has no fix, so Reading is network/account/IP fallback rather than accepted GNSS | Obtain a genuine outdoor Stroud-area GNSS fix and map-app acceptance; Qualcomm A-GPS modes currently fail at the operation-mode indication and the bridge remains a mock provider rather than a GNSS HAL |
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

The current post-acceptance state is:

```text
USB: postmarketOS CDC-NCM networking and SSH respond normally
Fastboot/ADB: unavailable while the running phone exposes the pMOS USB gadget
Kernel: r10 package booted as 7.1.0-rc1-sdm845
Waydroid: r51 camera safety/r53 codec installed; session stopped; rootfs mounts 0
Cellular: registered/connected; cellular-only DNS and HTTPS pass; Wi-Fi restored
Recovery: emergency reboot complete; D-state tasks 0; current I/O pressure 0
```

The post-reboot health gate passes. Continue to require normal SSH, no Waydroid
rootfs mounts, zero D-state tasks and zero current PSI I/O pressure before an
overlay operation. Do not
use fastboot/EDL or alter bootloader, slot or firmware state. The only reviewed
boot-image write is the exact manifest-verified kernel APK trigger documented
in [DISPLAY.md](DISPLAY.md).

The fixes package now includes `pmos-enable-ssh --apply`, an idempotent
systemd/OpenRC recovery helper that starts and persists `sshd` and verifies a
TCP/22 listener without changing firewall rules. It can be run from the
phone's local terminal or through the working SSH session.
