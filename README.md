# OnePlus 6T postmarketOS fixes

Reproducible, rollback-safe fixes and diagnostics for the OnePlus 6T
(`oneplus-fajita`) running postmarketOS.

The first validated fix creates persistent mobile data through NetworkManager.
It uses the standard `mobile-broadband-provider-info` database where that is
safe, understands its newer SIM GID1 field, adds an evidence-backed
compatibility overlay for older releases, and never guesses when several
carriers share one MCC/MNC.

Validated on 23-24 August 2026 with postmarketOS edge, NetworkManager 1.56.1,
ModemManager 1.25.95 and kernel `7.1.0-rc1-sdm845`.

## Safety boundary

These tools operate only inside the running postmarketOS installation. They do
not flash partitions, select boot slots, alter GPT attributes, change UFS boot
LUNs, invoke `qbootctl`, or reboot the phone. See
[docs/SAFETY.md](docs/SAFETY.md).

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

`make install DESTDIR=... PREFIX=/usr` is supported for package builders. No
service is silently enabled by the Makefile.

A local Alpine `APKBUILD` and its upstreaming checklist are in
[packaging/](packaging/). See [docs/UPSTREAM.md](docs/UPSTREAM.md) for why a
carrier-specific profile must not be placed in the OnePlus device package.

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

See [docs/DISPLAY.md](docs/DISPLAY.md). The display-driver fix is not yet
claimed; physical recovery and timestamped before/after evidence are required
before preparing a kernel candidate.

## Audio and microphone pairing

The audio layer now re-enables WirePlumber's ALSA hardware monitor and exposes
the real OnePlus card to `wpctl`, Phosh and PipeWire clients. An optional user
service pairs the default built-in microphone with the selected built-in
output: top mic for speaker, bottom mic for earpiece/voice call, and headset
mic for connected headphones. It leaves USB and Bluetooth routes untouched.

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
required before claiming a complete speakerphone output route.

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
| Tap-to-focus and truthful reticle | Maps a preview tap through crop/orientation into a real sensor metering region; installed r7/r1 correlates the result and uses amber/green/red state. |
| Filtered two-pass GPU scaling | Removes the Bayer-phase grid while retaining the intended field of view and practical preview speed. |
| Exposure, colour, contrast and detail controls | Changes the software ISP through standard controls and affects preview and saved images. |
| 1x–4x zoom and 2048x1536 stills | Provides useful framing controls and avoids saving only preview-resolution photographs. |
| Waydroid Camera3 bridge | Gives Android YUV/JPEG/private streams, EV metadata, low-light timing and rear tap-focus without vendor camera blobs. |
| Waydroid Mesa GPU software-ISP path | Uses the validated EGL/libyuv path for substantially faster Android preview processing than the CPU-only path. |
| Waydroid DMA-heap fallback | Keeps the Android HAL usable when the mainline phone image has no legacy gralloc allocator. |
| Waydroid Camera3 JPEG fix | Tracks the logical BLOB size so Android's JPEG footer is written where the framework expects it. |
| Waydroid SIGPIPE-safe provider teardown | A closed software-IPA socket is returned as an IPC error instead of terminating the Android camera provider. |
| Waydroid reduced preview source candidate | Large 4:3/16:9 Android preview requests can use a smaller aspect-preserving software-ISP source while retaining full-size JPEG capture; phone acceptance is pending. |
| Waydroid conditional preview mipmaps candidate | Equal-size and upscaled previews avoid regenerating an unnecessary EGL mipmap chain; true downscales retain mipmaps; phone acceptance is pending. |
| Waydroid redundant-clear candidate | The GPU ISP skips two full-frame clears that are immediately overwritten by full-screen Bayer/scaler passes; shaders, buffers and fallback paths are unchanged; phone acceptance is pending. |
| Waydroid NV12 fence-elision candidate | The GPU ISP avoids a second full GPU wait after synchronous RGBA readback and CPU NV12 conversion; direct RGB output keeps its fence; phone acceptance is pending. |
| Waydroid RGB private-preview candidate | Texture-only Android private previews can use RGBX/XBGR DMA-BUFs and avoid the NV12 GPU readback/conversion; YUV and encoder streams retain NV12; phone acceptance is pending. |
| Automated probes | Makes regressions repeatable across all cameras instead of relying only on visual inspection. |

Kernel r8, libcamera/IPA r24, `pipewire-spa-libcamera` r7, Snapshot r3 and
Advanced Snapshot r1 are installed. Exact r23 libcamera APKs are the immediate
libcamera rollback; the older
r20/r6/r2 complete userspace set is also retained. The native r24 stack passed
bounded captures on all three stable camera paths, rear tap/reset tests and
70/95-second continuous-focus stability runs. The Waydroid r35 overlay uses the
Mesa GPU software-ISP path, passed a clean three-camera Camera2
YUV/JPEG/private, autofocus and exposure probe, and produced a clean 1600x1200
JPEG capture.

Advanced Snapshot r1 is installed beside Snapshot. Its signed package and the
matching PipeWire SPA r7 package build reproducibly and passed one coherent
offline installation plus all-sensor acceptance. r7 carries
generation-correlated `AfState`; r1 keeps the focus marker amber while waiting,
turns it green only for metadata-confirmed focus and red for failure. Exact
r6/r0 APKs are retained as the immediate rollback.

The current native UI exposes a visible tap reticle plus Exposure, Colour,
Contrast, Detail, Zoom and Reset. The lower-layer focus instability is fixed:
both rear cameras now use bounded progressive tap-focus and return to
continuous monitoring without moving the lens. The UI is not yet an
Android-level camera application; that work continues in the separately
maintained Advanced Snapshot project. HDR, flash integration, calibrated
colour/lens shading, temporal denoise and Android vendor computational
processing are not claimed. See
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
Optional Play Store/GAPPS initialization and its read-only package verifier are
documented in [docs/WAYDROID-GAPPS.md](docs/WAYDROID-GAPPS.md). No Google image
or APK is included in this repository.

Before any overlay operation, run
`pmos-check-waydroid-health --status --processes`. It reports stale rootfs
mounts, both PSI I/O pressure classes (`some` and `full`) and D-state helper
commands without stopping services or writing storage. The installer repeats
the mount and I/O checks itself, so it refuses access even when this report is
not run.

To reproduce the current r7/r1-to-r7/r2 UI update, stage the unchanged r7
PipeWire SPA, the r2 app packages and the exact r7/r1 rollback in isolated
repositories:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r2 \
  install
```

That command is simulation-only by default. It verifies the device, immutable
six-APK manifest, pinned public key, hashes, signatures, installed baseline and
exact two-app-package solver result while requiring PipeWire to remain at r7.
After reviewing its evidence, repeat it with `--apply` to use the guarded
service/world-file checks and all-sensor health test. Use the `rollback`
operation for the exact reverse transition. See
[docs/CAMERA_GENERATIONS.md](docs/CAMERA_GENERATIONS.md).

The equivalent low-level simulation is:

```sh
stage=/absolute/path/to/camera-r7-r2
sudo apk add --simulate --upgrade --allow-untrusted --network=no \
  --interactive=no --repository "$stage/candidate" \
  "$stage/candidate/aarch64/advanced-snapshot-0.1.0-r2.apk" \
  "$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r2.apk"
```

Use `--allow-untrusted` only for locally built APKs whose source, version,
signature and hashes you verified. Require exactly both r1-to-r2 app upgrades,
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
4. adjust Exposure, Colour, Contrast, Detail or Zoom; and
5. use **Reset** to restore the tuned defaults for the active sensor.

Open **Advanced Snapshot** for the truthful reticle: amber means scanning,
green means libcamera reported `Focused`, and red means `Failed` or a transport
error. The fixed-focus front camera has no focus gesture.

The sliders affect both preview and saved output. HDR is intentionally shown as
unavailable because the open pipeline has no valid multi-frame merge and tone
mapping stage.

### Safe postmarketOS updates

After installing this package, use its guard for ordinary system upgrades:

```sh
pmos-safe-upgrade --simulate
pmos-safe-upgrade --apply
```

Simulation is the default. The guard refuses any transaction that touches
libcamera, PipeWire, WirePlumber, Snapshot, Advanced Snapshot or the OnePlus 6T
kernel, then points to the signed generation manager. Safe non-camera updates
use the cached package index after the gate; `apk upgrade --available` remains
outside this workflow.

### Location

Native GeoClue/ModemManager GNSS checks and the dry-run-first Waydroid location
bridge are documented in [docs/LOCATION.md](docs/LOCATION.md). The bridge is
explicitly a mock-provider diagnostic until the phone's native GNSS and an
Android map application have been tested; it does not pretend to provide a
vendor GNSS HAL. `pmos-check-location` now provides the read-only native
ModemManager/GeoClue report needed before using the bridge.

### NFC

The read-only NFC readiness report checks the controller/rfkill exposure,
device nodes and installed tag-reader tools without enabling polling. Run
`pmos-check-nfc --poll` only for an explicit tag test. NFC tag reading and
payment support remain unaccepted until the recovered phone can detect a real
tag. See [docs/NFC.md](docs/NFC.md).

## Project status

- Mobile data: live-tested, including replacement, disconnect/reconnect, DNS
  and HTTPS.
- Network time: enabled and synchronized; persistent systemd clock state is
  present.
- Messages: package, daemon, automated activation and touchscreen launch pass.
- Display: a read-only DRM/backlight diagnostic is packaged; the static-line
  and brightness-crash fix remains pending physical recovery and evidence.
- Cameras: installed native r8/r24/r7/r3 plus Advanced Snapshot r1 passed
  coherent package, D-Bus launch and all-sensor non-image acceptance. Exact
  r6/r0 APKs remain the immediate rollback; the Waydroid r35 lower layer passes
  all three Camera2 stream/AF/EV probes and the GPU/JPEG acceptance capture.
- Waydroid camera performance: an ARMv7/API-33 r37 RGB-private-preview bundle
  is built and reproducibly documented, but remains uninstalled pending
  physical recovery and before/after `preview`, `surface` and JPEG colour
  acceptance. The r35 overlay remains the rollback baseline.
- Next priorities: complete Advanced Snapshot visual photo/video acceptance
  and UI work. The first immutable camera manifest and guarded generation
  manager plus the ordinary-update safety gate pass host simulation, while the
  generation manager retains its real-phone simulation; next add the VibeMarketOS
  signed downstream repository, compatibility-gated published generations,
  then broaden Waydroid app testing and Play Store setup.
  See
  [docs/ROADMAP.md](docs/ROADMAP.md).
- Reboot persistence: still to be recorded in the validation log.
- Location: the read-only native report and dry-run Android bridge are
  documented; GNSS and Android map acceptance are pending device recovery, and
  no static Reading/Stroud coordinate has been hard-coded.
- Battery/power: the read-only `pmos-check-power` report, timed
  `pmos-measure-power` sampler and acceptance sequence are documented in
  [docs/POWER.md](docs/POWER.md); no unverified governor or suspend tweak has
  been forced.
- NFC: the read-only `pmos-check-nfc` report and explicit polling procedure are
  documented; physical controller and tag acceptance are pending device
  recovery.
- Waydroid safety: `pmos-check-waydroid-health` now provides the documented
  mount/I/O preflight; the reference phone currently fails it because stale
  rootfs mounts and storage pressure remain.
- Full modem-call audio, display-driver and battery-policy acceptance remain
  separate from this camera revision.

See [docs/VALIDATION.md](docs/VALIDATION.md) for sanitized test evidence.

## Upstream data sources

- [NetworkManager GSM settings](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/nm-settings-nmcli.html)
- [GNOME mobile-broadband-provider-info](https://gitlab.gnome.org/GNOME/mobile-broadband-provider-info)
- [SMARTY APN documentation](https://help.smarty.co.uk/en/articles/1155220-using-the-internet-after-you-ve-joined-smarty)
- [OnePlus 6T postmarketOS wiki](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29)

No device identifiers, account credentials, SIM serials, IMSIs, host keys or
unsanitized logs belong in this repository.
