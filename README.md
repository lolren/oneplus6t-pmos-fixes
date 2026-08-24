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

The reproducible camera stack covers all three sensors. It retains the IMX371
hardware-binned Quad Bayer fix, corrected gain models, rear contrast-detect
autofocus, filtered GPU scaling, centered statistics, highlight-aware exposure
and conservative open tone defaults. The current revision also adds a standard
software-ISP sharpness control, 2048x1536 still selection and real
crop/orientation-aware tap-to-focus in GNOME Snapshot. It also provides
standard ±1 EV compensation plus live Exposure, Colour, Contrast, Detail and
1x–4x Zoom controls with a visible tap-focus reticle.

Kernel r8, libcamera/IPA r22, `pipewire-spa-libcamera` r6 and Snapshot r3 are
installed. Exact r20/r6/r2 userspace packages remain staged as the preferred
rollback set; the intermediate r21 build is retained only as diagnostic
evidence. The installed stack passed bounded captures and control enumeration
on all three sensors, physical focus transport on both rear cameras, safe
rejection on the fixed-focus front camera, 2048x1536 negotiation on every
camera and measured live exposure compensation. HDR, flash integration,
calibrated colour/lens shading, temporal denoise and Android computational
processing are not claimed. See [docs/CAMERA.md](docs/CAMERA.md) for the feature matrix, evidence,
build route and installation boundary.

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

apk-tools 3 expects the repository root, then reads its `aarch64/` index and
fetches `snapshot-lang` from `noarch/`. Stage files accordingly, index both
sets, and simulate before installing:

```sh
mkdir -p patched/aarch64 patched/noarch
# Put aarch64 APKs in patched/aarch64/ and snapshot-lang in patched/noarch/.
apk index --allow-untrusted -o patched/aarch64/APKINDEX.tar.gz \
  patched/aarch64/*.apk patched/noarch/*.apk
apk upgrade --simulate --interactive=no --allow-untrusted --network=no \
  --repository "$PWD/patched" \
  libcamera libcamera-ipa pipewire-spa-libcamera snapshot snapshot-lang
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
- Cameras: installed r8/r22/r6/r3 stack passes three-camera capture,
  autofocus, tap-focus transport, sharpness, colour, highlight regulation,
  exposure compensation, grid, 30 fps and full-frame negotiation tests; the
  exact prior userspace package set is retained.
- Next priorities: Waydroid with Play Store and camera validation, followed by
  native GPS and a Waydroid location bridge. See [docs/ROADMAP.md](docs/ROADMAP.md).
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
