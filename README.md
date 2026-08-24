# OnePlus 6T postmarketOS fixes

Reproducible, rollback-safe fixes and diagnostics for the OnePlus 6T
(`oneplus-fajita`) running postmarketOS.

The first validated fix creates persistent mobile data through NetworkManager.
It uses the standard `mobile-broadband-provider-info` database where that is
safe, understands its newer SIM GID1 field, adds an evidence-backed
compatibility overlay for older releases, and never guesses when several
carriers share one MCC/MNC.

Validated on 23 August 2026 with postmarketOS edge, NetworkManager 1.56.1,
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

The reproducible camera stack now covers all three sensors. It retains the
front IMX371 hardware-binned Quad Bayer fix and adds corrected gain models,
rear one-shot/continuous autofocus, filtered GPU scaling that removes the
regular grid, centered statistics, per-channel highlight-aware automatic
exposure, sensor-specific open tone defaults, a saturation control and a
30 fps default for ordinary main-camera preview.

Kernel r8 and libcamera/IPA r19 are installed. The r19 packages passed isolated
live colour and light-step tests before installation, then passed installed
enumeration, bounded capture and repeated-open tests on all three sensors. The
exact r18 packages remain staged for rollback. HDR, flash integration,
calibrated colour/lens shading and Android computational processing are not
claimed. See [docs/CAMERA.md](docs/CAMERA.md) for the feature matrix, evidence,
build route and installation boundary.

## Project status

- Mobile data: live-tested, including replacement, disconnect/reconnect, DNS
  and HTTPS.
- Network time: enabled and synchronized; persistent systemd clock state is
  present.
- Messages: package, daemon, automated activation and touchscreen launch pass.
- Cameras: installed r8/r19 stack passes three-camera, autofocus, colour,
  highlight regulation, grid, 30 fps and repeated-open tests; exact r18
  rollback packages are retained.
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
