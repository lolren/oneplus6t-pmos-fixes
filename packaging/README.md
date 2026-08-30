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

The current checkout recipe is `0.1.0-r29`. A pure Alpine builder must also
install `python3` because the package check phase runs the Python bridge tests;
the `-d` flag skips only runtime dependency resolution, not those checks:

```sh
apk add alpine-sdk git python3
cd packaging
abuild -d
```

The verified r29 APK built from this checkout has SHA-256
`18d48eb99e2f1f6effb397fd2cd2f80871709799457568eb427fbe1580d5d87c`.
It is a local development artifact rather than a published release; install
it on a matching booted phone only after verifying the checksum and use
`apk add --allow-untrusted` when it is not in a configured repository.

On a pure Alpine edge builder, install `alpine-sdk`, `python3` and `git`, then
build the exact r25 commit without trying to resolve postmarketOS-only runtime
packages from Alpine's repositories:

```sh
git checkout fe01b51643ea7d157d805f25e9e07e7eaca42d07
cd packaging
SOURCE_DATE_EPOCH=1787935986 abuild -d
```

Use a normal locally configured `abuild` key. Reusing the release signing key
is required only for byte-identical signatures; package payload reproducibility
and the staged-content comparison do not depend on that private key.
When `PACKAGER_PRIVKEY` points to a manually supplied key, install its matching
public key in `/etc/apk/keys` inside the builder as well as in the build user's
`.abuild` directory. Otherwise the APK can be created successfully but the
final local repository-index update will reject its signature.

The current reproducible `noarch` build is also available from the
[runtime-r25 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r25).
Its `SHA256SUMS` entry is:

```text
781c1d7055a2d5530e127b3b16715b8270a5918412542661859d3bfea4c1ad1d  oneplus6t-pmos-fixes-0.1.0-r25.apk
```

Use `sha256sum -c SHA256SUMS` before installing the standalone APK. Since it
is not in a configured repository, installation uses
`apk add --allow-untrusted`; the package's ordinary dependencies remain
resolved through the target's configured repositories.

The package depends on the current owners of `getent`, `curl`, `ip`, `mmcli`,
`nmcli` and the Mobile Broadband Provider database. Runtime r17 and later
select postmarketOS's PipeWire UI backend and the PipeWire-Pulse systemd
socket; this replaces the conflicting real PulseAudio daemon while preserving
`pactl` through `pulseaudio-utils`. The cellular-only acceptance command uses
`resolvectl` when it is already present and otherwise falls back to `getent`,
avoiding a hard dependency on systemd-resolved. Other diagnostics continue to
degrade safely when optional systemd tools are absent, and the time helper
reports an explicit error outside a systemd installation.

Runtime r25 is built from commit `fe01b51643ea7d157d805f25e9e07e7eaca42d07`. Two clean `abuild -d` runs from
different absolute source/repository paths and UIDs with
`SOURCE_DATE_EPOCH=1787935986` produced byte-identical signed APKs. `-d` is
needed only by the pure Alpine builders because one declared runtime dependency
comes from postmarketOS rather than Alpine; the dependency remains in package
metadata and was resolved by an AArch64 installation simulation. Both builders
installed `alpine-sdk`, `python3` and `git`, and both ran the complete package
test suite. Signature
verification passes with the packaged development public key, whose SHA-256 is
`31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6`.
The APK's 101 regular files, 28 command links, file modes and link targets match
a clean `make install` stage exactly. Its metadata is `noarch`, and an AArch64
installation simulation resolves every runtime dependency. The exact APK
upgraded r24 on the reference phone; its installed Vanilla verifier, power
policy and location bridge hashes match the source. Google-free verification,
native LTE HTTPS, audio routing, Waydroid networking and the post-install
camera smoke test pass. It remains a pre-release while unplugged power,
map-app and real Android GNSS HAL acceptance are open.

The package installs a disabled system timer for the NetworkManager stale-
activated/QMAP bearer failure. `pmos-configure-mobile-data` enables it only
after committing a working managed UUID; `pmos-remove-mobile-data` disables it.
The timer never guesses a connection name or APN and does not cycle during a
ModemManager voice call.

`pmos-enable-ssh --apply` is an explicit, idempotent recovery helper for a
phone whose postmarketOS USB developer-mode NCM link answers ping but has no
usable SSH listener. It supports systemd and OpenRC, persists the `sshd`
service and verifies TCP/22. It intentionally does not modify nftables or
iptables; firewall changes remain a separately reviewed administrator action.

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
opt-in r7/r6 capture-safety, opt-in r7/r7 save-feedback, opt-in r7/r10
adjustment-safety, opt-in r7/r11 bounded-flash, the opt-in r26/r13 and r26/r14
lower-stack generations and legacy r7/r1 through r7/r4 immutable manifests, the current
and retained rollback public verification keys and the non-image all-sensor runner. It also installs
`pmos-safe-upgrade`, whose simulation-first gate blocks ordinary `apk upgrade`
transactions that touch camera-critical packages. The
manager does not contain APKs or a private key and does nothing without an
explicit operation. Install/rollback are simulation-only unless the graphical
login user passes `--apply`; see `docs/CAMERA_GENERATIONS.md`.

The package also installs `pmos-manage-display-kernel` and the immutable
`display-kernel-r8-r9.psv` manifest. It verifies the OnePlus compatibility
string, pinned public-key hash, signed repository indexes, APK hashes and the
exact one-package upgrade or downgrade before changing the installed kernel.
It is simulation-only unless the graphical login user passes `--apply`, never
reboots, and retains the r8 package as the explicit rollback. The r9 panel
change is source/package validated but still requires physical display
acceptance; see `docs/DISPLAY.md`.

The read-only `pmos-check-location`, `pmos-check-nfc`, `pmos-check-power`,
`pmos-measure-power` and `pmos-check-waydroid-health` reports are packaged as
well. They do not enable radios, change GPS state, poll NFC, modify power
policy or access a Waydroid overlay; the sampler only records timed battery
values, and the latter only reports whether stale mounts and I/O pressure make
an overlay operation unsafe.

The optional `oneplus6t-waydroid-location.service` is installed disabled. After
native GNSS and Waydroid health acceptance, an administrator may enable it to
run the documented ModemManager-to-Waydroid mock-provider bridge continuously.
It is not enabled by the package, follows the Waydroid container lifecycle so
it does not pull the container into every boot, and does not provide a vendor
GNSS HAL.

NFC userspace remains optional because `neard` is currently an Alpine testing
package. If it is available in the target channel, install `neard` and
`neard-systemd`, enable `neard.service`, and use `pmos-check-nfc --poll` for an
explicit kernel-NCI tag test.

The package also installs `pmos-run-device-acceptance`, which combines the
individual reports into a private evidence directory. Its camera, Messages,
GAPPS and NFC-poll checks are opt-in; the default run does not mutate the
phone. The packaged `pmos-test-cellular-only` and the runner's two
cellular-only options are also opt-in: they briefly disable Wi-Fi, verify
native and optional Waydroid traffic, then restore the exact initial Wi-Fi
radio/profile state. See `docs/ACCEPTANCE.md`.

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
