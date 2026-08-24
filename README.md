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

## Cameras

The reproducible camera stack covers all three sensors in native postmarketOS
and through an open Camera3 HAL in Waydroid.

| Feature | What it brings |
| --- | --- |
| IMX371 hardware binning | Removes the front camera's monochrome Quad Bayer grid without a proprietary remosaic stage. |
| Correct sensor gain models | Lets automatic exposure use the real 1x–16x range instead of making washed-out or underexposed decisions. |
| Highlight-aware auto exposure | Regulates light using post-white-balance channel histograms, reducing coloured clipping. |
| 15–30 fps frame-duration control | Lets clients trade frame rate for longer low-light exposure while fixed-rate video remains fixed. |
| Rear contrast autofocus | Drives both physical rear actuators and reports standard scan/focused/failed states. |
| Tap-to-focus and reticle | Maps a preview tap through crop/orientation into a real sensor metering region and shows immediate feedback. |
| Filtered two-pass GPU scaling | Removes the Bayer-phase grid while retaining the intended field of view and practical preview speed. |
| Exposure, colour, contrast and detail controls | Changes the software ISP through standard controls and affects preview and saved images. |
| 1x–4x zoom and 2048x1536 stills | Provides useful framing controls and avoids saving only preview-resolution photographs. |
| Waydroid Camera3 bridge | Gives Android YUV/JPEG/private streams, EV metadata, low-light timing and rear tap-focus without vendor camera blobs. |
| Automated probes | Makes regressions repeatable across all cameras instead of relying only on visual inspection. |

Kernel r8, libcamera/IPA r23, `pipewire-spa-libcamera` r6 and Snapshot r3 are
installed. Exact r22 libcamera APKs are the immediate rollback; the older
r20/r6/r2 complete userspace set is also retained. The native r23 stack passed
control enumeration and bounded 30-frame captures on all three stable camera
paths. The Waydroid r23 overlay passed all three Camera2 YUV/JPEG/private,
autofocus and exposure tests.

The current native UI exposes a visible tap reticle plus Exposure, Colour,
Contrast, Detail, Zoom and Reset. It is not yet an Android-level camera UI, and
an occasional unnecessary continuous-autofocus rescan has been observed on the
rear camera. Stabilizing that behavior and expanding truthful GUI controls are
active work. HDR, flash integration, calibrated colour/lens shading, temporal
denoise and Android vendor computational processing are not claimed. See
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
build the four package recipes:

```sh
git checkout 875bddba6538818f2c3c9849e184f40688ad5140
git apply --check --whitespace=nowarn \
  /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
git apply --whitespace=nowarn \
  /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
pmbootstrap -p "$PWD" build --arch aarch64 libcamera
pmbootstrap -p "$PWD" build --arch aarch64 pipewire
pmbootstrap -p "$PWD" build --arch aarch64 snapshot
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

Do not copy individual libraries into `/usr`, unload camera modules, or install
only part of the userspace set. Follow the offline, atomic simulation and
rollback procedure in [packaging/pmaports/README.md](packaging/pmaports/README.md).
Keep the prior exact-version APKs before changing the phone, close camera apps,
and require the simulation to show only the documented upgrades with no
removals. This userspace update does not require a reboot.

For the current r22-to-r23 native update, stage only the matching libcamera and
IPA APKs in an isolated repository and simulate before installing:

```sh
mkdir -p patched/aarch64
apk index --allow-untrusted -o patched/aarch64/APKINDEX.tar.gz \
  patched/aarch64/*.apk
apk upgrade --simulate --interactive=no --allow-untrusted --network=no \
  --repository "$PWD/patched" \
  libcamera libcamera-ipa
```

Use `--allow-untrusted` only for locally built APKs whose source, version and
hashes you verified. If and only if the simulation lists the expected camera
upgrades and no removal, rerun the same command without `--simulate`.

On the installed controls revision:

1. open **Camera**;
2. tap an object in either rear preview to request focus—the yellow square
   appears immediately, while the front camera correctly remains fixed-focus;
3. open the main menu and choose **Image Controls**;
4. adjust Exposure, Colour, Contrast, Detail or Zoom; and
5. use **Reset** to restore the tuned defaults for the active sensor.

The sliders affect both preview and saved output. HDR is intentionally shown as
unavailable because the open pipeline has no valid multi-frame merge and tone
mapping stage.

## Project status

- Mobile data: live-tested, including replacement, disconnect/reconnect, DNS
  and HTTPS.
- Network time: enabled and synchronized; persistent systemd clock state is
  present.
- Messages: package, daemon, automated activation and touchscreen launch pass.
- Cameras: installed native r8/r23/r6/r3 stack passes three-camera capture,
  controls and frame-duration enumeration; the Waydroid r23 lower layer passes
  all three Camera2 stream/AF/EV probes. Rear continuous-AF hunting and the
  higher-level native GUI remain active work.
- Next priorities: finish native AF/UI acceptance, broaden Waydroid app testing
  and Play Store setup, then native GPS and a Waydroid location bridge. See
  [docs/ROADMAP.md](docs/ROADMAP.md).
- Reboot persistence: still to be recorded in the validation log.
- Audio routing, display and power improvements are not included in this
  camera revision.

See [docs/VALIDATION.md](docs/VALIDATION.md) for sanitized test evidence.

## Upstream data sources

- [NetworkManager GSM settings](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/nm-settings-nmcli.html)
- [GNOME mobile-broadband-provider-info](https://gitlab.gnome.org/GNOME/mobile-broadband-provider-info)
- [SMARTY APN documentation](https://help.smarty.co.uk/en/articles/1155220-using-the-internet-after-you-ve-joined-smarty)
- [OnePlus 6T postmarketOS wiki](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29)

No device identifiers, account credentials, SIM serials, IMSIs, host keys or
unsanitized logs belong in this repository.
