# Alpine/postmarketOS package staging

`APKBUILD` packages the current checkout as a no-architecture Alpine package.
It is intended for local validation before a recipe is copied into an aports or
pmaports tree.

On an Alpine/postmarketOS build machine with `alpine-sdk` and a configured
abuild key:

```sh
cd packaging
abuild -r
```

The package depends on the current owners of `ip`, `mmcli`, `nmcli` and the
Mobile Broadband Provider database. `curl`, `resolvectl` and systemd time
tools remain optional: diagnostics degrade safely when they are absent, and the
time helper reports an explicit error outside a systemd installation.

The Messages diagnostic is optional and does not make Chatty a package
dependency. When Chatty is installed, its GLib utilities provide
`gapplication`; `busctl` enables window verification on systemd images. The
plain check does not D-Bus-activate an absent Chatty service.

Python 3 supports the optional V4L2 focus-control diagnostic. Camera kernel,
libcamera and tuning changes are deliberately not installed by this noarch
helper package; their separately reviewed pmaports integration is in
`packaging/pmaports/`.

The package also installs `pmos-camera-flash`. On hardware exposing writable
top-level `*:flash` LED channels, `pmos-camera-flash --status` reports the
available channels without changing them, while `--pulse` performs a capped,
restorable illumination pulse for Advanced Snapshot. The helper is explicit
and off by default; it is not a libcamera automatic-flash implementation.

The package also installs `pmos-manage-camera-generation`, the default r7/r5,
opt-in r7/r6 capture-safety, opt-in r7/r7 save-feedback and legacy r7/r1
through r7/r4 immutable manifests,
the public verification key and the non-image all-sensor runner. It also installs
`pmos-safe-upgrade`, whose simulation-first gate blocks ordinary `apk upgrade`
transactions that touch camera-critical packages. The
manager does not contain APKs or a private key and does nothing without an
explicit operation. Install/rollback are simulation-only unless the graphical
login user passes `--apply`; see `docs/CAMERA_GENERATIONS.md`.

The read-only `pmos-check-location`, `pmos-check-nfc`, `pmos-check-power`,
`pmos-measure-power` and `pmos-check-waydroid-health` reports are packaged as
well. They do not enable radios, change GPS state, poll NFC, modify power
policy or access a Waydroid overlay; the sampler only records timed battery
values, and the latter only reports whether stale mounts and I/O pressure make
an overlay operation unsafe.

The optional `oneplus6t-waydroid-location.service` is installed disabled. After
native GNSS and Waydroid health acceptance, an administrator may enable it to
run the documented ModemManager-to-Waydroid mock-provider bridge continuously.
It is not enabled by the package and does not provide a vendor GNSS HAL.

NFC userspace remains optional because `neard` is currently an Alpine testing
package. If it is available in the target channel, install `neard` and
`neard-systemd`, enable `neard.service`, and use `pmos-check-nfc --poll` for an
explicit kernel-NCI tag test.

The package also installs `pmos-run-device-acceptance`, which combines the
individual reports into a private evidence directory. Its camera, Messages,
GAPPS and NFC-poll checks are opt-in; the default run does not mutate the
phone. See `docs/ACCEPTANCE.md`.

Before upstreaming this recipe:

1. replace the local-checkout `builddir` with an immutable release or commit
   archive in `source`;
2. generate and commit its SHA-512 checksum with `abuild checksum`;
3. run `apkbuild-lint`, `pmbootstrap lint` and a clean aarch64 build; and
4. decide whether the scripts belong in a standalone package or an existing
   postmarketOS networking package.

Do not add a carrier-specific SMARTY profile to
`device-oneplus-fajita`. APNs belong to provider data, and the same phone may
use any carrier.
