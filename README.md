# OnePlus 6T postmarketOS fixes

Reproducible, rollback-safe fixes and diagnostics for the OnePlus 6T
(`oneplus-fajita`) running postmarketOS.

The first validated fix creates persistent mobile data through NetworkManager.
It uses the standard `mobile-broadband-provider-info` database where that is
safe, understands its newer SIM GID1 field, adds an evidence-backed
compatibility overlay for older releases, and never guesses when several
carriers share one MCC/MNC. A bounded watchdog also repairs the Qualcomm/QMAP
case where the carrier removes an Internet bearer but NetworkManager leaves its
profile falsely activated with a deleted data interface.

Validated on 23-28 August 2026 with postmarketOS edge, NetworkManager 1.56.1,
ModemManager 1.25.95 and kernel `7.1.0-rc1-sdm845`.

## Safety boundary

These tools do not use fastboot/EDL, select boot slots, alter GPT attributes,
change UFS boot LUNs, invoke `qbootctl`, or reboot the phone. The one explicit
exception to a userspace-only scope is the opt-in kernel generation manager:
applying its manifest-verified APK runs the normal postmarketOS package trigger
that rebuilds and writes the active postmarketOS boot image. Its exact rollback
APK must be retained first. See [docs/SAFETY.md](docs/SAFETY.md).

## Mobile data

The required runtime components are NetworkManager, ModemManager and
`mobile-broadband-provider-info`. Preview the carrier selection without making
changes:

```sh
./scripts/configure-mobile-data --dry-run
```

Install and activate one managed connection profile:

```sh
sudo ./scripts/configure-mobile-data
./scripts/check-mobile-data
```

To prove that ordinary native traffic really falls back to cellular, run the
guarded Wi-Fi-off check. Add Waydroid only when its session is already running:

```sh
./scripts/test-cellular-only
./scripts/test-cellular-only --with-waydroid
```

The command records the active Wi-Fi profile UUIDs before changing anything,
briefly disables Wi-Fi, checks the cellular default route, DNS and HTTPS, then
restores the original radio/profile state on success, failure or interruption.
It does not create or recycle a modem bearer. The helper validates sudo before
Wi-Fi is touched. For a normal user, only the Wi-Fi radio/profile mutations
and optional Android shell probes are elevated.

When installed as a package, the configurator also enables the five-minute
`oneplus6t-mobile-data-watchdog.timer`. The watchdog checks only the UUID that
this project records, does nothing to healthy or ordinarily inactive profiles,
defers during a voice call, and rate-limits reconnection attempts.

For a carrier missing from the databases, use its officially documented APN:

```sh
sudo ./scripts/configure-mobile-data \
  --provider "Carrier name" \
  --apn example.apn
```

Remove only the profile owned by this project:

```sh
sudo ./scripts/remove-mobile-data
```

The selection algorithm, diagnosis, contribution format and rollback behavior
are documented in [docs/CELLULAR.md](docs/CELLULAR.md).

## Optional system-wide installation

The scripts can run directly from a checkout. They can also be staged for a
future Alpine/postmarketOS package:

```sh
make test
sudo make install PREFIX=/usr/local
sudo pmos-configure-mobile-data --dry-run
```

`make install DESTDIR=... PREFIX=/usr` is supported for package builders. The
Makefile does not enable services; `pmos-configure-mobile-data` enables its
watchdog only after a managed profile activates successfully.

If USB networking answers ping but port 22 is unavailable, recover the
phone-side SSH service from its local terminal with the packaged helper:

```sh
sudo pmos-enable-ssh --apply
```

It supports both systemd and OpenRC, persists `sshd`, verifies the listener and
does not alter firewall rules. The recovery procedure and direct fallback
commands are in [docs/TRANSPORT.md](docs/TRANSPORT.md).

The last published signed `noarch` runtime package is the
[runtime-r25 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r25).
On a booted phone with normal postmarketOS repositories configured, download
the APK and checksum, verify them, then install the local package:

```sh
curl -fLO https://github.com/lolren/oneplus6t-pmos-fixes/releases/download/runtime-r25/oneplus6t-pmos-fixes-0.1.0-r25.apk
curl -fLO https://github.com/lolren/oneplus6t-pmos-fixes/releases/download/runtime-r25/SHA256SUMS
sha256sum -c SHA256SUMS
sudo apk add --allow-untrusted ./oneplus6t-pmos-fixes-0.1.0-r25.apk
```

`--allow-untrusted` is needed because this standalone package is not in the
phone's configured repository; the HTTPS download and committed checksum are
the integrity check. Its normal dependencies are still resolved from the
configured postmarketOS repositories.

The current checkout recipe is r41. It adds a guarded synchronizer for the two
Waydroid recording-profile files, alongside the r35 temporary sleep inhibitor
and root-only shell diagnostic for the SSH-launched camera probe. Every
Waydroid status and shell operation is now bounded, and a stopped or still-
frozen container is rejected before a probe can hang against a torn-down LXC
session. The location
bridge accepts both ModemManager key-value layouts with signal-safe cleanup,
and the NFC checker selects and restores the kernel-NCI adapter during an
explicit poll; none of these changes normal suspend behavior. Build it from
`packaging/` as documented in [packaging/README.md](packaging/README.md), or
use the source checkout directly with `make install`.

The clean r40 package built from commit `bbd7287` has SHA-256
`c93fcbb0e3554320d2bf7d20d0af7802c4564448fcc8bcaae8d5fb908eb9b725`.

Runtime r25 was built twice from commit `fe01b51` with a fixed source date;
the signed APKs were byte-identical. Every packaged file, command link and
regular-file mode matches a clean staged install, and the exact APK passes an
AArch64 installation simulation. Its SHA-256 is
`781c1d7055a2d5530e127b3b16715b8270a5918412542661859d3bfea4c1ad1d`.
The APK contains 101 regular files and 28 command links. Those exact bytes
upgraded r24 on the reference phone; the installed Vanilla verifier, power
policy and location bridge match the source hashes. Google-free identity, LTE
HTTPS, audio routing, three-camera enumeration, Waydroid networking and an
ID-0 displayed-surface camera smoke test pass. The tag remains a development
pre-release while unplugged battery and broader application acceptance remain
open.

The optional system service
`oneplus6t-waydroid-location.service` is installed disabled. After native GNSS
and Waydroid health acceptance, enable it explicitly with:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now oneplus6t-waydroid-location.service
```

Once enabled, it follows `waydroid-container.service` and does not start the
container merely for location. It temporarily grants the Android root shell's
mock-location app-op, uses the required `waydroid shell --` boundary, and
restores both the original fused provider and prior app-op when stopped.

For the normal daily-use setup, preview and then apply the carrier-neutral
mobile-data, network-time and microphone-route configuration together:

```sh
pmos-configure-daily-use
pmos-configure-daily-use --apply
```

Run it as the normal graphical user so `sudo` handles the privileged cellular
and time helpers while `systemctl --user` enables the audio route service.
The complete procedure, carrier-selection order and independent rollback
commands are in [docs/DAILY-USE.md](docs/DAILY-USE.md).

A local Alpine `APKBUILD` and its upstreaming checklist are in
[packaging/](packaging/). See [docs/UPSTREAM.md](docs/UPSTREAM.md) for why a
carrier-specific profile must not be placed in the OnePlus device package.

## Camera quality generation

The camera stack keeps the public libcamera control path intact while adding
OnePlus-specific tuning in a separate package. Rear tap-focus and manual focus
use the real IMX519/IMX376 actuator range; Advanced Snapshot r35 also reapplies
the selected focus request after opening its separate full-resolution still
stream, which is the stream that supplies the saved JPEG. The front IMX371 is
fixed-focus and is intentionally reported that way.

The current profiles use a moderate row-sum-preserving colour matrix on all
three sensors to suppress the remaining green cast without changing
equal-channel grey. Controlled IMX519 test-pattern output remains neutral after
the profile, and the stronger candidate reduced the residual green ratio in
the available secondary-rear and front captures. This is a bounded
open-pipeline correction, not a claim of factory calibration or Android
vendor-ISP parity; chart-based colour and lens-shading calibration remain open.

## Unattended acceptance run

After the phone is reachable, collect one reproducible evidence directory for
the daily-use checks:

```sh
pmos-run-device-acceptance --output "$HOME/oneplus6t-acceptance/run-1"
```

Add `--with-camera --close-camera-apps` for the bounded all-sensor focus and
stability test, `--with-messages` for Chatty activation, or
`--with-gapps` for the optional Waydroid Play Store package check. Use
`--cellular-only` to prove native Wi-Fi fallback or
`--cellular-only-waydroid` to include a running Android container. Both
cellular-only modes restore the original Wi-Fi state. The runner keeps
per-check logs and `summary.psv`; see
[docs/ACCEPTANCE.md](docs/ACCEPTANCE.md) for the safety boundary and privacy
notes.

## Time synchronization

A fresh installation with a 1970 clock can have working packet transport while
DNSSEC and HTTPS fail. Enable normal systemd network-time synchronization:

```sh
sudo ./scripts/configure-time-sync
```

If the initial clock must be seeded, pass a trusted Unix timestamp obtained on
another correctly synchronized machine. Do not obtain it from the phone while
the phone clock is wrong.

```sh
sudo ./scripts/configure-time-sync --epoch 1787485490 --timezone Europe/London
```

See [docs/TIME.md](docs/TIME.md) for the automatic boot behavior and checks.

## Messages

The installed GNOME Chatty application and its background daemon are healthy,
and both D-Bus and desktop-file activation create a window. Re-run the
privacy-safe diagnostic or request a fallback activation as the login user:

```sh
./scripts/check-messages
./scripts/check-messages --activate
```

See [docs/MESSAGES.md](docs/MESSAGES.md) for the measured result, display-driver
evidence and the completed touchscreen confirmation.

## Display diagnostics

The read-only display report records DRM connector/mode state, backlight
values, kernel command-line data and filtered DRM/panel/DPU messages. It is
intended to capture the horizontal-static and brightness-crash symptom without
changing the display:

```sh
./scripts/check-display --output /tmp/oneplus6t-display-report.txt
```

See [docs/DISPLAY.md](docs/DISPLAY.md). The original opt-in,
source/package-validated serialized-brightness kernel candidate is available
from the
[display-r8-r9 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/display-r8-r9).
Kernel r10 retains that change and adds bounded Qualcomm Venus firmware-error
recovery; it is installed and booted on the reference phone with r8 retained by
`data/kernel-r8-r10.psv`. The exact signed stage is published in the
[kernel-r8-r10 pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/kernel-r8-r10).
Brightness remains unclaimed until timestamped
before/after reports and the full display acceptance sequence pass.

## USB transport diagnostics

When the phone is connected to the Linux host, distinguish its postmarketOS
USB-network mode from ADB or fastboot with the read-only host command:

```sh
./scripts/check-device-transport \
  --output /tmp/oneplus6t-device-transport.txt
```

In particular, `ping=pass` plus `ssh_tcp=pass` but
`ssh_banner=missing` means the USB/network kernel path is alive while the
phone-side SSH userspace is not responding. An empty `fastboot devices` result
is normal while the phone is exposing CDC-NCM rather than fastboot endpoints.
See [docs/TRANSPORT.md](docs/TRANSPORT.md) for the safe interpretation.

## Audio and microphone pairing

The audio layer now requires postmarketOS's PipeWire backend, re-enables
WirePlumber's ALSA hardware monitor and exposes the real OnePlus card to
`wpctl`, Phosh, native applications and Waydroid. This prevents a second real
PulseAudio daemon from taking the compatibility socket while WirePlumber owns
the hardware. An optional user service pairs the default built-in microphone
with the selected built-in output: top mic for speaker, bottom mic for
earpiece/voice call, and headset mic for connected headphones. It leaves USB
and Bluetooth routes untouched.

Install and enable it with:

```sh
make test
sudo make install PREFIX=/usr/local
systemctl --user daemon-reload
systemctl --user enable --now oneplus6t-audio-route.service
pmos-check-audio-routing
```

The route policy and the current q6voice/callaudiod boundary are documented in
[docs/AUDIO.md](docs/AUDIO.md). A real modem-call speakerphone test remains
required before claiming a complete speakerphone output route. The live
PipeWire-Pulse graph already passes native microphone capture, Waydroid AAC
recording and Waydroid playback through the physical speaker.

## Cameras

The reproducible camera stack covers all three sensors in native postmarketOS
and through an open Camera3 HAL in Waydroid.

| Feature | What it brings |
| --- | --- |
| IMX371 hardware binning | Removes the front camera's monochrome Quad Bayer grid without a proprietary remosaic stage. |
| Correct sensor gain models | Lets automatic exposure use the real 1x–16x range instead of making washed-out or underexposed decisions. |
| Highlight-aware auto exposure | Regulates light using post-white-balance channel histograms, reducing coloured clipping. |
| 15–30 fps frame-duration control | Lets clients trade frame rate for longer low-light exposure while fixed-rate video remains fixed. |
| Stable progressive rear autofocus | Reuses the last good lens position, searches outward only as needed, validates the final position and resumes continuous mode without a reset sweep. |
| Tap-to-focus and truthful reticle | Maps a preview tap through crop/orientation into a real sensor metering region; r7 transport and Advanced Snapshot r24 correlate the result and use amber/green/red state. |
| Manual rear focus | Exposes `LensPosition` 0.0–2.0 in Advanced Snapshot; the simple IPA maps it to the bounded 400–800 actuator span and the fixed-focus front disables it. |
| Filtered two-pass GPU scaling | Removes the Bayer-phase grid while retaining the intended field of view and practical preview speed. |
| Exposure, colour, contrast and detail controls | Changes the software ISP through standard controls and affects preview and saved images. |
| Manual shutter and analogue gain | Disables automatic regulation and submits standard `ExposureTime` and `AnalogueGain` values in microseconds and linear gain units; the IPA clamps them to the active sensor. |
| Gamma and sensor calibration | Advanced Snapshot exposes a standard `Gamma` tone control plus a phone-width per-sensor calibration dialog for repeatable exposure, white balance, 3×3 colour matrix, contrast, detail and focus settings; profiles are keyed by stable camera identity. |
| Automatic/manual white balance | Keeps statistics-driven AWB as the default, transports standard red/blue `ColourGains` arrays through PipeWire and lets Advanced Snapshot persist bounded gains per physical sensor. |
| Writable colour correction | Exposes the standard nine-element `ColourCorrectionMatrix` on all three native cameras while white balance is manual; the r34 downstream profiles add a moderate, grey-preserving green-cast correction, while the app retains bounded user/chart overrides without claiming factory calibration. |
| 1x–4x zoom and 2048x1536 stills | Provides useful framing controls, keeps the tappable value chip in the toolbar instead of over the mode selector, and avoids saving only preview-resolution photographs. |
| Bounded rear hardware flash | Provides an explicit, opt-in LED pulse through `pmos-camera-flash`; it saves/restores both rear LED channels, caps the pulse at 5 seconds and is disabled for the front camera. |
| Waydroid Camera3 bridge | Gives Android YUV/JPEG/private streams, EV metadata, low-light timing, rear tap-focus and standard rear manual focus without vendor camera blobs. |
| Complete clean-image camera provider | Bundles the reviewed 32-bit legacy provider, implementation libraries and VINTF declaration and sets both host camera properties with exact rollback, so cameras work after a fresh ARM64 Vanilla initialization. |
| Verified Google-free Waydroid | Pins an official Vanilla/MAINLINE image pair by archive and extracted-image hashes and verifies that GMS, GSF and Play Store are absent. |
| Waydroid Mesa GPU software-ISP path | Uses the validated EGL/libyuv path for substantially faster Android preview processing than the CPU-only path. |
| Waydroid EGL NV12 channel-order fix | Corrects the GPU B,G,R,A readback conversion so front-camera skin tones are not rendered purple; the [r36 bundle](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r36-nv12) is installed and its single-output preview passed all three cameras. |
| Waydroid multi-output software ISP | Debayers one Bayer input once, keeps a linear RGB preview and coalesces NV12 encoder/analysis consumers with a centred crop; this removes the one-output limit and avoids repeated GPU readback. |
| Waydroid private-preview cap | Limits only CameraX private previews to 1280x960 so 720p recording stays on a practical sensor mode; larger explicit YUV/JPEG photography modes remain available. |
| Waydroid contiguous NV12 GPU target | Writes a compatible linear Y+UV allocation with one filtered GPU draw, avoiding RGBA readback and CPU colour conversion; unsupported layouts retain the safe libyuv fallback. The r49 direct-path baseline is published, and its source-fence-corrected r50 runtime is retained by the installed r52 clean-Vanilla generation. |
| Waydroid post-processor fence synchronization | Waits once on each GPU-written source fence before mapped YUV/JPEG post-processing, preventing front/auxiliary stills from reading partially rendered rows while direct-only Android surfaces retain asynchronous completion fences. |
| Waydroid Camera3 worker-lifecycle drain | Completes asynchronous YUV/JPEG workers and pending Camera3 descriptors before close/reset, restarts workers after `flush()`, and supplies valid monotonic timestamps when the simple V4L2 path reports zero; this prevents stale requests poisoning the next camera open. |
| Waydroid recording profiles and Codec2 policy | Publishes guarded main/front 480p/720p H.264/AAC `EncoderProfiles`, retains Android's software fallback and adds a tightly scoped hardware-codec sandbox. Auxiliary video is deliberately not advertised after a reproducible Venus teardown fault. |
| Waydroid recording-profile synchronizer | `pmos-sync-waydroid-camera-profiles` repairs stale image-level `media_profiles*.xml` mappings so Android sees rear main ID 0 and front ID 2 for ordinary video; it keeps only a non-recording ID 1 framework sentinel, requires a stopped/unmounted Waydroid rootfs, records exact backups, and supports rollback. |
| Waydroid Venus hardware H.264 | Drives the SDM845 encoder at `/dev/video12`; r53 completes repeated H.264/AAC recordings and clean teardown. Exact main-rear r49 video averages 11.78 fps, while exact-HAL front r50 video averages 24.77 fps, so performance remains sensor/path dependent. |
| Waydroid DMA-heap fallback | Keeps the Android HAL usable when the mainline phone image has no legacy gralloc allocator. |
| Waydroid Camera3 JPEG fix | Tracks the logical BLOB size so Android's JPEG footer is written where the framework expects it. |
| Waydroid SIGPIPE-safe provider teardown | A closed software-IPA socket is returned as an IPC error instead of terminating the Android camera provider. |
| Waydroid reduced preview source candidate | Large 4:3/16:9 Android preview requests can use a smaller aspect-preserving software-ISP source while retaining full-size JPEG capture; phone acceptance is pending. |
| Waydroid conditional preview mipmaps candidate | Equal-size and upscaled previews avoid regenerating an unnecessary EGL mipmap chain; true downscales retain mipmaps; phone acceptance is pending. |
| Waydroid redundant-clear candidate | The GPU ISP skips two full-frame clears that are immediately overwritten by full-screen Bayer/scaler passes; shaders, buffers and fallback paths are unchanged; phone acceptance is pending. |
| Waydroid NV12 fence-elision candidate | The fallback GPU ISP avoids a second full GPU wait after synchronous RGBA readback and CPU NV12 conversion; direct RGB and contiguous NV12 output keep completion fences; broader phone acceptance is pending. |
| Waydroid RGB private-preview candidate | Texture-only Android private previews can use RGBX/XBGR DMA-BUFs and avoid the NV12 GPU readback/conversion; YUV and encoder streams retain NV12. The follow-on native-fence candidate exports GPU completion to Android when supported and keeps a synchronous fallback; phone acceptance is pending. Download the [r37/r38 development bundles](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r37-r38). |
| Automated probes | Makes regressions repeatable across all cameras instead of relying only on visual inspection. |

The repository retains the earlier r8/r24/r7/r3 userspace camera baseline and
publishes the newer libcamera r34 / Advanced Snapshot r36 / PipeWire r8 line. The
reference phone is reachable over USB CDC-NCM/SSH. The installed Waydroid r52
clean-Vanilla layer retains the exact r51/r50 camera binaries and r36 colour
correction, adds the complete legacy provider, and includes reproducible
patches `0013`–`0019` for mixed RGB/NV12 streams, preview sizing, direct
contiguous NV12 output, source-fence-safe mapped post-processing, worker-safe
Camera3 shutdown, rear manual focus and active-array-correct AF regions. The
r53-static10-focus provider overlay is installed and has passed repeated
preview reopen plus manual-focus, tap-focus and full three-camera probes;
ordinary third-party camera-app soak testing remains open.
Kernel r10
and Codec2 r53 are installed. The exact r50 source completed a clean 198-target
Android build and a full three-camera Camera2 run: all JPEGs decode and report
zero repeated row discontinuities. A real front Aperture H.264/AAC recording
also decoded fully at about 24.77 fps with correct colour and no former green
layout band. Main-rear video remains in the 11.78 fps class, and auxiliary
hardware encoding is deliberately disabled after two reproducible post-stop
Venus IRQ storms; its preview and still-capture paths remain enabled.

The current source line is libcamera/IPA r34, PipeWire SPA r8 and Advanced
Snapshot r36; the reference phone is still running the accepted libcamera r33
pair and the installed r34 app while the r34 colour follow-up and r36 app pair
await phone installation. The app source is commit
`df308e9d95ba9d90ac6866010db3b95ce9d11de4`; the exact AArch64 package pair is
built and artifact-validated. The controls panel and calibration dialog now
include automatic/manual white balance, per-sensor red/blue gains and a
bounded 3×3 colour matrix. The r34 IPA selects the
documented sensor-specific profiles and applies a moderate grey-preserving
green-cast correction; equal-channel test-pattern output remained neutral and
custom matrix requests were accepted on IMX371, IMX376 and IMX519, while automatic mode
restored each stream. The 1.0× chip is contained by the top toolbar and no
longer covers the photo/video/QR selector.
Native and Waydroid rear focus controls also pass their live
metadata/actuator probes. A factory CCM, lens shading and Android vendor
processing remain separate image-quality gates.

The current native UI source exposes a visible **Image Controls** entry, tap
reticle plus Exposure, White Balance, Colour Matrix, Colour, Contrast, Detail,
Gamma, Zoom, Reset and an
opt-in rear **Hardware flash** switch when the helper is installed. The Camera
Calibration dialog can save those standard controls, including AWB mode,
red/blue gains and the optional matrix, per physical sensor and
optionally restore a deliberate manual focus position. The r36 camera-page
overlay drawer keeps these controls alongside the live preview, and its
Sensor default, Neutral, Natural, Vivid and Custom presets update the visible
image without hiding the camera view. Its visible Green-cast correction action
applies the conservative matrix to the selected camera and turns off automatic
white balance; Reset restores the automatic path. The lower-layer focus
instability is fixed: both rear cameras now use bounded progressive tap-focus
and return to continuous monitoring without moving the lens. Advanced Snapshot
additionally offers a manual rear-lens slider and explicitly returns to
continuous AF on Reset. The UI is not yet an
Android-level camera application; that work continues in the separately
maintained Advanced Snapshot project. HDR, calibrated
colour/lens shading, temporal denoise and Android vendor computational
processing are not claimed. The hardware switch is not automatic flash
metering or HDR. See
[docs/CAMERA.md](docs/CAMERA.md) for native details and
[docs/WAYDROID.md](docs/WAYDROID.md) for Android requirements, build,
installation, feature explanations, validation and rollback.

### Camera requirements, installation and use

The camera packages target the OnePlus 6T on postmarketOS edge with the
matching SDM845 kernel and the exact libcamera 0.7.2, PipeWire 1.6.8 and
Snapshot 50.0 sources documented here. Building requires a current
`pmbootstrap`, a reviewed pmaports checkout and enough space for clean aarch64
buildroots. Installing requires root, but building does not.

Apply the reviewed integration patch to the documented pmaports base, then
build the five package recipes:

```sh
git checkout 875bddba6538818f2c3c9849e184f40688ad5140
git apply --check --whitespace=nowarn \
  /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
git apply --whitespace=nowarn \
  /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
pmbootstrap -p "$PWD" build --arch aarch64 libcamera
pmbootstrap -p "$PWD" build --arch aarch64 pipewire
pmbootstrap -p "$PWD" build --arch aarch64 snapshot
pmbootstrap -p "$PWD" build --arch aarch64 advanced-snapshot
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

Do not copy individual libraries into `/usr`, unload camera modules, or install
only part of the userspace set. Follow the offline, atomic simulation and
rollback procedure in [packaging/pmaports/README.md](packaging/pmaports/README.md).
Keep the prior exact-version APKs before changing the phone, close camera apps,
and require the simulation to show only the documented upgrades with no
removals. This userspace update does not require a reboot.

The Android/Waydroid camera bundle is a separate ARMv7 runtime. Build and
package it with `scripts/build-waydroid-camera` and
`scripts/package-waydroid-camera`, stop the Waydroid session/container, and
install it atomically with `sudo scripts/install-waydroid-camera`. That helper
backs up only its managed targets and prints the exact rollback directory.
Follow [docs/WAYDROID.md](docs/WAYDROID.md) for the patch order, GPU mode,
package hashes, clean three-camera probe and rollback command.
The r51 auxiliary-video safety release remains historical evidence. The
[r52 clean-Vanilla release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r52-vanilla-complete)
keeps that safety policy and adds every provider/property dependency needed by
a clean Vanilla image; auxiliary preview and still capture remain available
while camera-ID-2 hardware encoding stays blocked.
The arm64 hardware encoder is a second, independently rollback-safe overlay.
Fetch its pinned Android 13 sources, build, package and install with:

```sh
scripts/prepare-waydroid-v4l2-codec-sources /tmp/codec-sources
ANDROID_NDK_ROOT=/path/to/android-ndk-25.2.9519653 \
WAYDROID_LINK_LIB64=/path/to/android13/system/lib64:/path/to/apex-libs \
  scripts/build-waydroid-v4l2-codec \
  /tmp/codec-sources /tmp/codec-build /tmp/codec-stage
scripts/package-waydroid-v4l2-codec \
  /tmp/codec-stage /tmp/oneplus6t-waydroid-v4l2-codec-r53
sudo scripts/install-waydroid-v4l2-codec /tmp/codec-stage
```

Stop Waydroid first. The installer refuses mounted rootfs and active I/O
pressure, backs up nine exact targets and prints its rollback directory. Full
source revisions, library requirements, hashes, feature explanations and
runtime verification are in [docs/WAYDROID.md](docs/WAYDROID.md). The r53
archive and manifest are byte-reproducible and published in the
[r53 pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-v4l2-codec-r53);
their exact hashes and the r51 historical release are recorded there.
The default Google-free deployment, exact image hashes, update policy and
read-only verifier are documented in
[docs/WAYDROID-VANILLA.md](docs/WAYDROID-VANILLA.md). Optional Play Store/GAPPS
initialization remains separate in
[docs/WAYDROID-GAPPS.md](docs/WAYDROID-GAPPS.md). No Google image or APK is
included in this repository.

Before any overlay operation, run
`pmos-check-waydroid-health --status --processes`. It reports stale rootfs
mounts, both PSI I/O pressure classes (`some` and `full`) and D-state helper
commands without stopping services or writing storage. The installer repeats
the mount and I/O checks itself, so it refuses access even when this report is
not run.

To reproduce the current r7/r4-to-r7/r5 UI update, stage the unchanged r7
PipeWire SPA, the r7 app packages and the exact r7/r4 rollback in isolated
repositories:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r5 \
  install
```

That command is simulation-only by default. It verifies the device, immutable
six-APK manifest, pinned public key, package and repository-index signatures,
hashes, installed baseline and exact two-app-package solver result while
requiring PipeWire to remain at r7.
After reviewing its evidence, repeat it with `--apply` to use the guarded
service/world-file checks and all-sensor health test. Use the `rollback`
operation for the exact reverse transition. See
[docs/CAMERA_GENERATIONS.md](docs/CAMERA_GENERATIONS.md).

A matching development AArch64 stage is available from the
[camera-r7-r5 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r5).
Verify its `SHA256SUMS` file, extract the archive, and pass the extracted
directory as `--stage`. The release is explicitly not a production build and
still requires the simulation and phone-side health gates below.

An opt-in r8 capture-safety candidate is available from the
[camera-r7-r6 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r6).
Use it with `data/camera-generation-r7-r6.psv`; it keeps PipeWire r7 and
rolls back to the r7 Advanced Snapshot pair. It is source/package validated but
not hardware-accepted, so the default manager manifest remains r7/r5.

An opt-in r9 save-feedback candidate is available from the
[camera-r7-r7 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r7).
Use it with `data/camera-generation-r7-r7.psv`; it keeps PipeWire r7, upgrades
the app pair from r8 to r9 and rolls back to r8. The app now reports a visible
error when a capture produces no usable file. It is source/package validated
but not hardware-accepted, so the default manager manifest remains r7/r5.

An opt-in r10 adjustment-safety candidate is available from the
[camera-r7-r10 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r10).
Use it with `data/camera-generation-r7-r10.psv`; it keeps PipeWire r7, upgrades
the app pair from r9 to r10 and rolls back to r9. r10 cancels stale image-
adjustment helpers when a newer slider request, camera switch or page teardown
supersedes them. It is source/package validated but not hardware-accepted, so
the default manager manifest remains r7/r5.

An opt-in r11 bounded rear-flash candidate is available from the
[camera-r7-r11 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r11).
Use it with `data/camera-generation-r7-r11.psv`; it keeps PipeWire r7, upgrades
the Advanced Snapshot pair from r10 to r11 and retains r10 for rollback. The
app's Hardware flash switch launches the bounded `pmos-camera-flash` helper
only for rear stills and restores LED state on completion or interruption. It
is source/package validated but not hardware-accepted, so the default manager
manifest remains r7/r5.

The current opt-in lower-stack candidate is available from the
[camera-r26-r15 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r26-r15).
Use it with `data/camera-generation-r26-r15.psv`; it updates the matching
libcamera/IPA r26 pair and Advanced Snapshot r15 while retaining the exact
r24/r11 rollback stage. r15 aligns bounded whole-frame handheld translation
before its opt-in linear-light Software HDR merge. It remains source/package
validated rather than hardware-accepted, and the default manager manifest
stays r7/r5 until live camera and lifecycle testing is possible.

The equivalent low-level simulation is:

```sh
stage=/absolute/path/to/camera-r7-r5
sudo apk add --simulate --upgrade --allow-untrusted --network=no \
  --interactive=no --repository "$stage/candidate" \
  "$stage/candidate/aarch64/advanced-snapshot-0.1.0-r7.apk" \
  "$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r7.apk"
```

Use `--allow-untrusted` only for locally built APKs whose source, version,
signature and hashes you verified. Require exactly both r4-to-r7 app upgrades,
no PipeWire operation and no removal, then rerun the same command without
`--simulate`. The complete guide records repository indexing, service handling,
the expected two-line world-file diff and guarded rollback cleanup. Reproduce
the historical r6/r0-to-r7/r1 lower-stack update by explicitly passing
`--manifest data/camera-generation-r7-r1.psv` and its matching stage.

On installed Snapshot r3:

1. open **Camera**;
2. tap an object in either rear preview to request focus—the yellow square
   appears immediately, while the front camera correctly remains fixed-focus;
3. open the main menu and choose **Image Controls**;
4. adjust Exposure, Colour, Contrast, Detail, Gamma or Zoom; and
5. use **Camera calibration** to save a repeatable profile for the active
   sensor, or **Reset** to restore its tuned defaults.

Open **Advanced Snapshot** for the truthful reticle: amber means scanning,
green means libcamera reported `Focused`, and red means `Failed` or a transport
error. In **Image Controls**, use **Manual focus position** on either rear
camera to hold 0 (far) through 2 (near); tapping the preview replaces that
lock with one-shot AF, and **Reset** restores continuous AF. The fixed-focus
front camera has no focus gesture or manual slider.

The sliders affect both preview and saved output. The Advanced Snapshot r36
build also exposes opt-in Software HDR when its helper is installed; it
uses three bracketed JPEG captures, confidence-gated global-translation
alignment and a linear-light merge. This is not the same as Android-vendor HDR:
local/non-rigid subject motion, rotation, parallax, lens shading, calibrated
colour, temporal denoise and proprietary ISP processing remain outside the
open stack.

### Safe postmarketOS updates

After installing this package, use its guard for ordinary system upgrades:

```sh
pmos-safe-upgrade --simulate
pmos-safe-upgrade --apply
```

Simulation is the default. The guard refuses any transaction that touches
libcamera, PipeWire, WirePlumber, Snapshot, Advanced Snapshot or the OnePlus 6T
kernel, then points to the signed generation manager. Safe non-camera updates
use the cached package index after the gate, and the applied operation list is
compared with the successful simulation before the command is reported as
successful. `apk upgrade --available` remains outside this workflow.

### Location

Native GeoClue/ModemManager GNSS checks, the dry-run-first Waydroid location
bridge and its optional disabled system service are documented in
[docs/LOCATION.md](docs/LOCATION.md). It accepts raw
NMEA and formatted decimal fields from fresh-UTC-gated `mmcli --location-get`
polls, or gpsd JSON;
the bridge is explicitly a mock-provider integration rather than a vendor GNSS
HAL. The reversible Android fused-provider bridge, service lifecycle and
rollback are validated, but the current phone report has no GNSS coordinates;
a fresh outdoor native fix, map-application acceptance and a native Android
GNSS HAL remain open.
`pmos-check-location` provides the read-only native ModemManager/GeoClue report
needed before using the bridge.

### NFC

The read-only NFC readiness report checks the controller/rfkill exposure,
device nodes and installed tag-reader tools without enabling polling. When
`neard`/`nfctool` is installed it uses the kernel-NCI path; `nfc-list` remains
an external-reader fallback. The recovered phone has `neard.service` enabled,
and `nfctool -l` exposes its `nfc0` adapter. Run `sudo pmos-check-nfc --poll`
only for an explicit tag test; the checker restores the adapter after polling.
NFC tag reading and payment support remain unaccepted until a real tag is
detected. See [docs/NFC.md](docs/NFC.md).

### Battery and suspend

The immediate drain found on the reference phone was a failed Waydroid
location service restarting every five seconds. Runtime r25 fixes and
rate-limits that path and leaves continuous GNSS bridging disabled by default.
The phone now uses Google-free Waydroid with frozen-container idle behavior.
`pmos-configure-power` previews, applies and exactly rolls back a battery-only
five-minute suspend policy without changing AC behavior, governors, radios,
charging limits or firmware. One RTC-bounded suspend/resume cycle passed;
repeated cycles and unplugged measurements are still required before claiming
Android battery parity; see
[docs/POWER.md](docs/POWER.md).

## Project status

The current requirement-by-requirement audit is maintained in
[docs/STATUS-MATRIX.md](docs/STATUS-MATRIX.md). In summary:

- host-side APN selection, time-sync, audio routing, display candidate,
  camera stack, Waydroid overlays, location bridge, NFC/power reports and
  update guard are implemented and tested;
- signed AArch64 camera r28 and Advanced Snapshot r24 development packages,
  plus the complete Waydroid r52 clean-Vanilla bundle, are published; the
  installed r53-static10-focus camera overlay, kernel r10 and byte-reproducible Codec2 r53 complete repeated
  main/front recording. The
  exact r10/r8 and r53 artifacts are also public. Android frame-rate work and
  a safe non-Venus auxiliary encoder remain open;
- live SMARTY cellular routing, DNS and HTTPS pass; Google-free Waydroid
  networking and all-camera preview pass. Previously accepted rear/front
  video, microphone and speaker playback remain installed; time-after-boot,
  modem-call audio,
  display stability, saved-image colour/quality, native camera video, outdoor
  GNSS, NFC, battery and rollback persistence still need their respective
  device tests;
- Android-vendor HDR, calibrated colour/lens shading and a vendor GNSS HAL are
  not claimed because the open stack does not provide those proprietary
  components.

The current USB evidence is CDC-NCM with ping and password SSH working. ADB
and fastboot remain unavailable, so bootloader/raw-partition operations are
still out of scope. Userspace/Waydroid work and the exact package-managed
kernel generation can be managed over the working SSH transport.

See [docs/VALIDATION.md](docs/VALIDATION.md) for sanitized test evidence.
The requirement-by-requirement implementation and device-acceptance audit is
kept in [docs/STATUS-MATRIX.md](docs/STATUS-MATRIX.md).

## Upstream data sources

- [NetworkManager GSM settings](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/nm-settings-nmcli.html)
- [GNOME mobile-broadband-provider-info](https://gitlab.gnome.org/GNOME/mobile-broadband-provider-info)
- [SMARTY APN documentation](https://help.smarty.co.uk/en/articles/1155220-using-the-internet-after-you-ve-joined-smarty)
- [OnePlus 6T postmarketOS wiki](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29)

No device identifiers, account credentials, SIM serials, IMSIs, host keys or
unsanitized logs belong in this repository.
