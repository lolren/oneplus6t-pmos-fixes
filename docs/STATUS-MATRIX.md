# OnePlus 6T completion matrix

This document is the current audit of the requested OnePlus 6T
postmarketOS work. It separates source implementation, host validation and
physical-phone acceptance. A passing host test does not imply that a package
is installed or that the phone has passed the corresponding runtime test.

Audit date: 2026-08-31.

## Feature status

| Area | Implemented in the repositories | Host evidence | Remaining requirement |
| --- | --- | --- | --- |
| Daily-use setup | One command sequences the existing APN, network-time and audio-route helpers with dry-run/apply modes and independent rollback | The live phone currently has SMARTY LTE attached, `NTPSynchronized=yes` in Europe/London, and active PipeWire/WirePlumber/pipewire-pulse services; wrapper, shell syntax, dry-run/apply sequencing and package staging tests pass | Run the full apply path in the phone's graphical user session and verify real modem-call routes |
| Mobile data | NetworkManager profile helper; provider database/GID-aware MVNO selection; UUID-scoped stale-bearer watchdog; managed rollback; guarded native/Waydroid cellular-only acceptance command with exact device-bound Wi-Fi restoration | Live phone: SMARTY profile connected, LTE, 71% signal, home registration, packet service attached, cellular IPv4 ping and HTTPS pass; the packaged cellular-only native/Waydroid route/DNS/HTTPS test and watchdog recovery also pass | Test an additional non-SMARTY SIM to broaden carrier acceptance |
| Network time | systemd network-time configuration and read-only check | Live phone reports `NTP=yes`, `NTPSynchronized=yes`, `Timezone=Europe/London`, and cellular HTTPS succeeds | Recheck only after a base-system time-service change |
| Messages | Chatty/D-Bus/desktop activation diagnostic and fallback activation | Fixture-backed activation checks pass; prior touchscreen launch was recorded | Reconfirm on the recovered display |
| Audio routing | PipeWire-Pulse backend, WirePlumber hardware-monitor configuration, reversible built-in microphone policy and a Waydroid playback bridge floor/runtime-property overlay | Native microphone capture is non-silent; Waydroid microphone recording and physical-speaker playback pass; Android `STREAM_MUSIC` is 15/15, AudioFlinger stream 3 is 0 dB, the fixed-gain Android probe is 100% unmuted on the speaker sink, and its monitor level matches a same-level native tone; backend/conflict, route-policy and installation tests pass | Compare the user's quiet Android application against a live native stream at the same host sink; test earpiece, speakerphone and headset during a real modem call, then repeat after reboot |
| Display/kernel safety | Read-only DRM/backlight diagnostic; serialized Samsung brightness writes; r10 bounds Venus recovery IRQ work only during firmware error; r8 rollback manifest | r10 is installed; ordinary main/front recordings pass. Both auxiliary stop orders cause a delayed IRQ spike; watchdog/emergency reboot recovery completed with clean filesystems, zero pressure and zero D-state tasks | Do not deliberately exercise auxiliary Venus encoding again; strengthen recovery containment separately and complete brightness slider/lock/suspend acceptance |
| Native camera sensors | IMX371/IMX376/IMX519 modes, Quad-Bayer handling, conservative AE, image controls, stable rear AF, normalized rear manual focus, standard automatic/manual white balance and writable 3×3 colour correction; r35 adds the stronger sensor-specific row-sum-preserving green-cast correction plus verified simple-pipeline test patterns; the simple IPA exposes `LensPosition` 0.0–2.0 plus `AwbEnable`, `ColourGains` and `ColourCorrectionMatrix` | Live phone is on libcamera/IPA r35, with r35 profiles active on all three sensors; controlled final frames reduced rear green ratios 1.304→1.238 and 1.256→1.181, while the front neutral-tile check remained approximately 1.062→1.063; rear 60-second focus windows completed with zero restarts/lens requests and front completed 120 frames | Compare saved images against a controlled target/chart; values are not measured factory calibration; dioptre calibration, lens shading and Android computational processing remain open |
| Native camera UI | Advanced Snapshot r36 source with a labelled always-visible **Image Controls** button, phone-width colour calibration, Gamma, automatic/manual white balance, per-sensor matrix profiles, visible green-cast correction action, tap-focus reticle, rear manual focus, automatic/manual exposure, shutter/gain, exposure/colour/contrast/detail controls, unobstructed toolbar 1x–4x pinch/slider zoom, latest-frame preview scheduling, save-failure feedback, guarded rear hardware-flash switch, opt-in software HDR and serialized camerabin teardown; r37 aligns the visible correction preset with the native r35 matrix | Source commit `df308e9` and the verified r36 archive build/validator; the r36 pair is installed; the r37 source commit `71e3378aacf59c87696af8acd2086418dfa0ea64` and release-signed AArch64 pair pass the app build, package and manifest checks; the 1.0× chip and calibration dialog passed full-resolution screen inspection; all three sensors accepted identity/custom matrix requests and automatic restoration; native focus helper regression and live r35 smoke pass | Install r37 from the [Advanced Snapshot release](https://github.com/lolren/advanced-snapshot/releases/tag/r37-green-cast), then verify saved chart images, playable video, HDR output, rear LED restoration, Green-cast Apply/Reset behavior and measured scene-specific calibration values; factory CCM/lens shading remain open |
| Rear hardware flash | Bounded `pmos-camera-flash` helper for the OnePlus `white:flash`/`yellow:flash` channels; saves/restores brightness and handles interruption | Fixture test covers pulse, restoration, off and no-hardware paths | Run `pmos-camera-flash --status` and one rear still capture on the recovered phone; confirm no front-camera pulse |
| Android camera enumeration | Complete clean-image legacy provider plus open Camera3 HAL for all three sensors, YUV/JPEG/private streams, AF/EV metadata, mixed RGB/NV12 coalescing, private-preview cap, source-fence-safe post-processing, worker-lifecycle drain, rear manual focus and guarded main/front recording profiles | Current provider map is ID 0 rear main, ID 1 rear auxiliary and ID 2 front; r53-static10-focus is installed; the latest protected full probe returned valid YUV/JPEG/private previews on all three IDs, zero JPEG row discontinuities, rear AF states `[3,4]` on IDs 0/1 and fixed-focus state `[0]` on ID 2; r35 also handles denied sleep inhibition and the root-only shell boundary; r40's parser-safe profile mapping leaves ordinary video profiles only on IDs 0/2, and installer, patch-integrity and source-compile fixtures pass | Soak an ordinary Android camera application across open/close and app switching; keep auxiliary ID 1 ordinary recording unadvertised until a non-Venus path or kernel/Codec2 fix passes teardown |
| Android camera performance/video | GPU software ISP with NV12 colour correction, coalesced multi-output processing, ranked Venus Codec2, MMAP compressed output, exact single-plane NV12 layout/lifetime and metadata-only temporary stride discovery | Main rear ID 0 produced a decodable 9.877-second 1280×720 H.264/AAC file with 280 video frames; front ID 2 produced a decodable 9.959-second file with 248 video frames. The existing safe main control reaches about 29.78 fps; the parser reports no ordinary 480p/720p profile for auxiliary ID 1. Both auxiliary teardown orders still trigger the same Venus IRQ storm, so the no-profile safety policy remains | Investigate an explicit software encoder or kernel/Codec2 fix; continue long capture, app switching and suspend/resume only on IDs 0 and 2 |
| Android camera image quality | Sensor-aware format/order handling, EGL NV12 red/blue correction, JPEG decoding/row-integrity checks, source-fence synchronization and Camera2 AF-region/manual-focus forwarding | Exact r50 all-camera JPEGs have zero repeated row discontinuities; private front video has normal colour without purple or green/static lines; the r53 manual/tap probes pass | Compare a real face/colour chart, exposure, focus and back-camera sharpness against Android; vendor HDR/CCM/lens shading are not implemented |
| Waydroid apps | Pinned Google-free Vanilla image pair, read-only no-Google verifier, guarded camera/Codec2 installers, health preflight, streamed Camera2 probe and persistent PipeWire playback bridge safeguards | Android 13 Vanilla is installed; GMS, GSF, Play Store and the GMS property are absent. r53-static10-focus camera and r53 Codec2 overlays are present; r40 profile repair passed all-camera preview and front ID 2 H.264/AAC recording without a reboot; the idle container remains freeze-on-idle outside probe invocations | Validate ordinary applications and map-location behavior; never encode auxiliary rear ID 1 in Venus |
| Location | Read-only ModemManager/GeoClue report; fresh-UTC-gated polling for raw/NMEA, gpsd and formatted-ModemManager fixes; reversible Android app-op/provider bridge tied to Waydroid lifecycle; coordinate-free applied logs | The r29 bridge accepts both aggregate and indexed ModemManager state output, passes 17 parser/service tests, and a live 60-second apply/termination run restored the original GPS state and removed its mock provider; the current report still has no GNSS coordinates | Keep the continuous one-second bridge disabled except when Android location is needed; repeat outdoors until a fresh native fix is obtained, then install and accept a map app; a real Android GNSS HAL/A-GPS remains open |
| NFC | Read-only controller/rfkill/device-node report, kernel-NCI `nfctool` discovery/poll path with explicit adapter selection and exit cleanup, plus libnfc fallback | r32 live report shows enabled `neard.service` and `nfc0` with the expected NCI protocols; a bounded privileged no-tag poll selected `nfc0` and restored `Powered: No`; fixtures cover no-poll, adapter selection, cleanup and unprivileged refusal | Place a real tag beside the phone, record UID/NDEF data and repeat after restarting the userspace reader; payment support is not claimed |
| Battery life | Google-free Waydroid, frozen-container idle, location-loop fix, read-only report/sampler and exact-rollback five-minute battery suspend policy | The 381-restart location leak is stopped; with probes idle the connected phone is about 96% CPU-idle. One RTC-bounded s2idle cycle passed with modem/Wi-Fi/display/camera recovery, and the five-minute policy is applied with exact rollback. Fuel gauge estimates about 88% design capacity | Repeat suspend cycles and collect matched unplugged screen-off, screen-on, modem and camera drain before claiming improvement or Android parity |
| Update safety | Camera-critical package guard, immutable generation manifests, backups and retained rollback generations | Update-guard, generation-manager and VibeMarketOS tests pass | Re-run the health gate and complete a real-phone rollback/persistence test |

## Transport evidence

The host-side `scripts/check-device-transport` report is deliberately separate
from phone runtime acceptance. On 2026-08-31 it confirmed the OnePlus as
`ID_MODEL=OnePlus_6T` with a CDC-NCM interface, a working
`172.16.42.2/16` host link and ping to `172.16.42.1`; TCP/22 accepts a
connection and sends an SSH banner, but the authenticated SSH session channel
times out before a command can run. `fastboot devices` remains empty and ADB
shows only the separately attached Pixel. The NCM link is alive, but the
management channel is not currently usable for package or service changes;
this is not a bootloader or flashing session.

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
USB: postmarketOS CDC-NCM networking, ping, TCP/22 and SSH banner respond;
     authenticated SSH session channel stalls before command execution
Fastboot/ADB: unavailable while the running phone exposes the pMOS USB gadget
Kernel: r10 package booted as 7.1.0-rc1-sdm845
Waydroid: r52 clean-Vanilla camera/r53 codec installed; r53-static10-focus provider overlay verified for manual/tap focus; Android 13 Vanilla verified; bridge property/quantum safeguards live; stopped cleanly with rootfs mounts 0
Cellular: registered/connected; cellular-only DNS and HTTPS pass; Wi-Fi restored
Recovery: emergency reboot complete; D-state tasks 0; current I/O pressure 0
```

The post-reboot health gate passes, but the management gate is incomplete while
the authenticated SSH channel stalls. Continue to require a working command
channel, no Waydroid rootfs mounts, zero
D-state tasks and zero current PSI I/O pressure before an overlay operation. Do not
use fastboot/EDL or alter bootloader, slot or firmware state. The only reviewed
boot-image write is the exact manifest-verified kernel APK trigger documented
in [DISPLAY.md](DISPLAY.md).

The fixes package now includes `pmos-enable-ssh --apply`, an idempotent
systemd/OpenRC recovery helper that starts and persists `sshd` and verifies a
TCP/22 listener without changing firewall rules. If TCP/22 and the banner work
but the authenticated session channel stalls, run
`pmos-enable-ssh --apply --restart` from the phone's local terminal. It can be
run from the phone's local terminal or through a working SSH session; the
restart form must be local because it intentionally interrupts SSH.
