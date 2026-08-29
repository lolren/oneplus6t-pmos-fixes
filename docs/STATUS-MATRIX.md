# OnePlus 6T completion matrix

This document is the current audit of the requested OnePlus 6T
postmarketOS work. It separates source implementation, host validation and
physical-phone acceptance. A passing host test does not imply that a package
is installed or that the phone has passed the corresponding runtime test.

Audit date: 2026-08-29.

## Feature status

| Area | Implemented in the repositories | Host evidence | Remaining requirement |
| --- | --- | --- | --- |
| Daily-use setup | One command sequences the existing APN, network-time and audio-route helpers with dry-run/apply modes and independent rollback | Wrapper, shell syntax, dry-run/apply sequencing and package staging tests pass | Run the apply path in the phone's graphical user session and verify live bearer, synchronized clock and real modem-call routes |
| Mobile data | NetworkManager profile helper; provider database/GID-aware MVNO selection; UUID-scoped stale-bearer watchdog; managed rollback; guarded native/Waydroid cellular-only acceptance command with exact device-bound Wi-Fi restoration | Cold-boot r23 and the newly reinserted SMARTY SIM both register through database-selected `mob.asm.net`; the corrected packaged test passes cellular-only native route/DNS/HTTPS plus Waydroid raw-IP/DNS and restores the exact Wi-Fi profile. Explicit bearer-loss/watchdog recovery also passes | Test an additional non-SMARTY SIM to broaden carrier acceptance |
| Network time | systemd network-time configuration and read-only check | Configuration/fixture tests pass; after the real cold boot `systemd-timesyncd` is active, `NTPSynchronized=yes`, Europe/London is selected and cellular HTTPS succeeds | Recheck only after a base-system time-service change |
| Messages | Chatty/D-Bus/desktop activation diagnostic and fallback activation | Fixture-backed activation checks pass; prior touchscreen launch was recorded | Reconfirm on the recovered display |
| Audio routing | PipeWire-Pulse backend, WirePlumber hardware-monitor configuration, reversible built-in microphone policy and a Waydroid playback bridge floor/runtime-property overlay | Native microphone capture is non-silent; Waydroid microphone recording and physical-speaker playback pass; Android `STREAM_MUSIC` is 15/15, the fixed-gain Android probe is 100% unmuted and the speaker monitor measured -9.03 dB RMS / -6.02 dB peak; backend/conflict, route-policy and installation tests pass | Test earpiece, speakerphone and headset during a real modem call, then repeat after reboot |
| Display/kernel safety | Read-only DRM/backlight diagnostic; serialized Samsung brightness writes; r10 bounds Venus recovery IRQ work only during firmware error; r8 rollback manifest | r10 is installed; ordinary main/front recordings pass. Both auxiliary stop orders cause a delayed IRQ spike; watchdog/emergency reboot recovery completed with clean filesystems, zero pressure and zero D-state tasks | Do not deliberately exercise auxiliary Venus encoding again; strengthen recovery containment separately and complete brightness slider/lock/suspend acceptance |
| Native camera sensors | IMX371/IMX376/IMX519 modes, Quad-Bayer handling, conservative AE, image controls and stable rear AF; r25 adds sustained-rise AF reference filtering; r26 adds standard manual shutter/gain controls | Full pMOS host suite, deterministic AF regression, clean AArch64 libcamera r26 build and signed runtime/IPA package verification pass; hardware acceptance pending | Install the r26 candidate and repeat live preview, still, focus, automatic/manual exposure, colour and suspend/resume tests |
| Native camera UI | Advanced Snapshot r16 source with tap-focus reticle, automatic/manual exposure, shutter/gain, exposure/colour/contrast/detail controls, 1x–4x pinch/slider zoom, latest-frame preview scheduling, save-failure feedback, guarded rear hardware-flash switch, opt-in software HDR with bounded handheld translation alignment and serialized camerabin teardown | Pinned GTK/GStreamer build and formatting pass; the follow-up lifecycle source commits `279ffe0`, `f08d927` and `2c93c2f` are patched and documented, but the new r16 package still needs an AArch64 build, signing and touchscreen acceptance | Verify visual preview latency, aligned HDR output, saved images, manual exposure, playable video and rear LED restoration on the phone |
| Rear hardware flash | Bounded `pmos-camera-flash` helper for the OnePlus `white:flash`/`yellow:flash` channels; saves/restores brightness and handles interruption | Fixture test covers pulse, restoration, off and no-hardware paths | Run `pmos-camera-flash --status` and one rear still capture on the recovered phone; confirm no front-camera pulse |
| Android camera enumeration | Complete clean-image legacy provider plus open Camera3 HAL for all three sensors, YUV/JPEG/private streams, AF/EV metadata, mixed RGB/NV12 coalescing, private-preview cap, source-fence-safe post-processing and guarded main/front recording profiles | r52 is installed on a clean ARM64 Vanilla image; Android reports the provider running and the corrected Camera2 probe completed two consecutive sequential ID 0/1/2 preview runs with `valid=3 total=3`, waiting for each asynchronous camera close; no new kernel/provider fatal appeared. Installer and patch-integrity fixtures pass | Complete all-camera full/JPEG visual acceptance; keep auxiliary recording unadvertised until a non-Venus path or kernel/Codec2 fix passes teardown |
| Android camera performance/video | GPU software ISP with NV12 colour correction, coalesced multi-output processing, ranked Venus Codec2, MMAP compressed output, exact single-plane NV12 layout/lifetime and metadata-only temporary stride discovery | Main rear H.264/AAC fully decodes at 11.78 fps; a dedicated safe control reaches 29.78 fps. Front r50 video fully decodes at 24.77 fps with AAC. Both auxiliary teardown orders trigger the same Venus IRQ storm, so installed r52 retains the r51 no-profile safety policy and the probe hard-refuses it | Investigate an explicit software encoder or kernel/Codec2 fix; continue long capture, app switching and suspend/resume only on main/front |
| Android camera image quality | Sensor-aware format/order handling, EGL NV12 red/blue correction, JPEG decoding/row-integrity checks and source-fence synchronization | Exact r50 all-camera JPEGs have zero repeated row discontinuities; private front video has normal colour without purple or green/static lines | Compare a real face/colour chart, exposure, focus and back-camera sharpness against Android; vendor HDR/CCM/lens shading are not implemented |
| Waydroid apps | Pinned Google-free Vanilla image pair, read-only no-Google verifier, guarded camera/Codec2 installers, health preflight, streamed Camera2 probe and persistent PipeWire playback bridge safeguards | Android 13 Vanilla is installed; GMS, GSF, Play Store and the GMS property are absent. r52 camera and r53 Codec2 overlays are present; all three preview/surface probes, Android networking, native LTE HTTPS, audio services and post-suspend ID-0 smoke tests pass; the idle container freezes and the probe runner now thaws it automatically for SSH-launched runs | Validate ordinary applications, safe IDs 0/1 recording and map-location behavior after the image replacement; never encode camera ID 2 in Venus |
| Location | Read-only ModemManager/GeoClue report; fresh-UTC-gated polling for raw/NMEA, gpsd and formatted-ModemManager fixes; reversible Android app-op/provider bridge tied to Waydroid lifecycle; coordinate-free applied logs | Native and Android private fixes previously passed. Runtime r25 accepts Vanilla's default app-op output, snapshots/restores GPS source and refresh-rate state, rate-limits failures and passes 16 bridge/service tests | Keep the continuous one-second bridge disabled except when Android location is needed; install and accept a map app; a real Android GNSS HAL/A-GPS remains open |
| NFC | Read-only controller/rfkill/device-node report, kernel-NCI `nfctool` discovery/poll path and libnfc fallback | NFC report fixtures cover both no-poll and `nfctool` polling selection | Install/enable `neard`, detect a real tag and validate a userspace reader |
| Battery life | Google-free Waydroid, frozen-container idle, location-loop fix, read-only report/sampler and exact-rollback five-minute battery suspend policy | The 381-restart location leak is stopped; with probes idle the connected phone is about 96% CPU-idle. One RTC-bounded s2idle cycle passed with modem/Wi-Fi/display/camera recovery, and the five-minute policy is applied with exact rollback. Fuel gauge estimates about 88% design capacity | Repeat suspend cycles and collect matched unplugged screen-off, screen-on, modem and camera drain before claiming improvement or Android parity |
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
- [WAYDROID-VANILLA.md](WAYDROID-VANILLA.md) — default Google-free image
  generation, exact hashes, verification and update/rollback policy;
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
Waydroid: r52 clean-Vanilla camera/r53 codec installed; Android 13 Vanilla verified; bridge property/quantum safeguards live; stopped cleanly with rootfs mounts 0
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
