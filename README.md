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

## Current status: read this first

This table is the authoritative top-level status as of 2026-08-31. The long
sections below and the linked documents retain the detailed implementation and
historical release record. “Implemented” means that source and package gates
pass; “accepted” means that the corresponding behavior was also observed on
the physical OnePlus 6T. Those are intentionally kept separate.

| Area | Current state | What still remains |
| --- | --- | --- |
| USB and SSH | The booted phone is reachable over the postmarketOS USB CDC-NCM gadget; the recent r38/r49 package updates were completed through the working management path | Keep a local-terminal recovery path for the separate case where TCP/22 answers but an authenticated SSH channel stalls; no fastboot/EDL work is needed for these packages |
| Mobile data | NetworkManager/ModemManager configuration is provider-aware, uses the standard provider database plus a guarded compatibility overlay, understands SIM GID1 and repairs the stale Qualcomm/QMAP bearer case; SMARTY LTE registration, DNS, IPv4 and HTTPS pass on the reference SIM | Live-test another carrier/SIM; the project cannot prove every network without the carrier's APN and a real modem test |
| Network time | Network time is enabled and the reference phone reported synchronized UTC with `Europe/London`; time configuration is separate from cellular profile selection | Recheck after any base-system time-service change |
| Native audio | PipeWire/WirePlumber hardware monitoring, native microphone capture, Waydroid AAC capture and speaker playback are implemented; the route policy pairs top microphone with speakerphone and bottom microphone with earpiece, with headset routes left alone | Complete a real modem-call test for earpiece, speakerphone and headset switching; Android application loudness still needs a matched live comparison |
| Display and kernel safety | Kernel r10 is installed with serialized Samsung brightness writes and bounded Venus error recovery; reports, package manifests and rollback artifacts are present | Finish the physical brightness-slider, lock/unlock and suspend sequence; do not deliberately exercise the unsafe auxiliary Venus encoder again |
| Native cameras | The matching lower stack is kernel r10, libcamera/IPA r35 and PipeWire SPA r8. IMX371, IMX376 and IMX519 modes, progressive rear AF, rear manual focus, standard AE/AWB controls and the row-sum-preserving green-cast profile are implemented and lower-layer probes pass | Capture controlled saved images on both rear cameras, validate sharpness/colour against a chart and complete native video, HDR and flash checks |
| Advanced Snapshot | The independently named r38 app and language package is installed as an app-only update. It provides visible live controls, tap-focus reticle, fresh still-stream autofocus, rear manual focus, pinch zoom, exposure/shutter/gain, WB, Gamma, colour profiles, calibration, green-cast correction, software HDR and bounded flash integration | Physical r38 saved-photo/focus acceptance still needs a normal graphical user session and repeatable near/far targets; Android-vendor image parity is not claimed |
| Waydroid | Google-free Android 13 Vanilla, the open Camera3 provider and Codec2 overlays are installed. All three camera IDs preview; rear-main ID 0 and fixed-focus front ID 1 produce validated 720p H.264/AAC recordings; the profile synchronizer and persistent session unit are installed | The session is deliberately stopped/disabled while the phone is at the greeter. Log in graphically, enable the session only after the health gate, then test ordinary apps, camera-app soaks, audio and location. Auxiliary rear ID 2 video remains disabled after a reproducible Venus teardown fault |
| Location | Read-only ModemManager/GeoClue reporting and a reversible ModemManager-to-Waydroid mock-provider bridge are implemented with cleanup and rollback | The current phone report still has no fresh GNSS coordinates. Obtain an outdoor native fix before testing maps; a vendor Android GNSS HAL/A-GPS path is not implemented |
| NFC | Controller/rfkill reports, `nfc0` discovery, bounded kernel-NCI polling and adapter restoration are implemented | Read a real tag/NDEF payload; payment support is not claimed |
| Battery | The runaway Waydroid location loop was stopped, idle containers freeze safely, and one bounded s2idle cycle plus exact-rollback power policy passed | Repeat unplugged screen-off/screen-on/modem/camera measurements before claiming Android-level battery life |
| Update safety | Camera-critical package generations have signed manifests, checksums, simulation gates, retained rollback and a safe-upgrade wrapper | Complete a real-phone rollback/persistence test after the graphical session and camera acceptance gates pass |

### Installed reference baseline

The reference phone currently has the following separation of concerns:

| Layer | Installed/current artifact | Repository or release |
| --- | --- | --- |
| Kernel | r10, booted on the OnePlus 6T | This repository's display/kernel generation documentation |
| Native camera lower layer | libcamera/IPA r35 and PipeWire SPA r8 | Reviewed pmaports camera generation; rollback is retained |
| Native camera UI | Advanced Snapshot r38 | [r38 fresh-still-autofocus](https://github.com/lolren/advanced-snapshot/releases/tag/r38-fresh-still-autofocus), installed app-only without reboot |
| Device helper | `oneplus6t-pmos-fixes` local checkout recipe r49 | r49 is the current reproducible source revision; the published noarch runtime is [r48 graphical-session](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r48-graphical-session) |
| Android container | Google-free Vanilla image, r53-static10-focus provider and Codec2 r53 overlays | Waydroid guides and releases in this repository |
| Waydroid session | Installed but disabled/stopped until a normal graphical login | `oneplus6t-waydroid-session.service`; no SSH-scoped session is used |

Recent r38/r49 changes were userspace/package-only. They did not change the
bootloader, fastboot/EDL state, boot slots, GPT/UFS layout, firmware or raw
partitions, and they did not reboot the phone.

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

## Installation methods

There are several layers in this project, and they are intentionally installed
separately. Use the smallest method that matches the feature you need:

1. Install the no-architecture helper package for mobile data, time, audio,
   diagnostics, update guards and the release wrappers.
2. Install Advanced Snapshot r38 separately when only the camera UI/fresh-still
   autofocus path is required.
3. Install the reviewed native r35/r36 camera generation only when the matching
   libcamera, PipeWire SPA and application versions are required together.
4. Install the Waydroid Vanilla/camera/Codec2 overlays only after the container
   health checks pass and a normal graphical user session exists.

All package installation commands below are intended for a booted postmarketOS
phone. A USB CDC-NCM or ordinary network connection is enough; fastboot and EDL
are not used. Run simulation commands first, retain the exact rollback assets,
close camera applications before lower-layer changes, and apply package
transactions as the normal graphical user unless a command explicitly says it
must be run locally as root. No command in the app-only or helper paths reboots
the phone.

### 1. Run from a source checkout

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

For a phone reached over USB networking, copy or clone this repository on the
phone and run the commands there. The usual developer-mode address is
`172.16.42.1`, but the address is environment-dependent:

```sh
ssh user@PHONE_IP
git clone https://github.com/lolren/oneplus6t-pmos-fixes.git
cd oneplus6t-pmos-fixes
make test
```

The checkout is safe to use without installing anything. `make test` exercises
the shell, Python and fixture-backed policy tests. To install the commands
system-wide from the checked-out source, use a staging directory first when
building a package, or:

```sh
sudo make install PREFIX=/usr/local
```

This installs helpers and service files only. It does not install a kernel,
libcamera, PipeWire, Waydroid image or private signing key.

### 2. Install the published no-architecture runtime helper

The public [runtime-r48 graphical-session
release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r48-graphical-session)
is the easiest package path. It contains the reproducible helper commands,
diagnostics, update policy, release wrapper and the disabled Waydroid-session
unit. The current source checkout is r49 and refreshes the r38 installer and
session-unit details; r49 is not a separately published release artifact.

On the booted phone, download the APK and its committed checksum file. GitHub
CLI is convenient, but downloading the same two files from the release page in
a browser is equivalent:

```sh
mkdir -p "$HOME/Downloads/oneplus6t-pmos-fixes-r48"
cd "$HOME/Downloads/oneplus6t-pmos-fixes-r48"
gh release download runtime-r48-graphical-session \
  --repo lolren/oneplus6t-pmos-fixes \
  --pattern '*-r48.apk' \
  --pattern SHA256SUMS
runtime_apk=$(find . -maxdepth 1 -type f \
  -name 'oneplus6t-pmos-fixes-*-r48.apk' -print -quit)
test -n "$runtime_apk"
awk -v file="${runtime_apk#./}" '$2 == file' SHA256SUMS | sha256sum -c -
```

The standalone APK is not in the phone's configured repository, so
`--allow-untrusted` is expected after the HTTPS download and checksum have
been checked. The package's ordinary dependencies are still resolved from the
configured postmarketOS repositories:

```sh
sudo apk add --simulate --upgrade --allow-untrusted --no-interactive \
  "$runtime_apk"
sudo apk add --upgrade --allow-untrusted --no-interactive \
  "$runtime_apk"
apk info -a oneplus6t-pmos-fixes | sed -n '1,20p'
```

The simulation should contain one `oneplus6t-pmos-fixes` install/upgrade and
must not remove the kernel, camera stack, Waydroid, NetworkManager or
ModemManager. If it proposes removals or a different architecture, stop and
fix the repository state before applying. The package is noarch; native
camera and Codec2 binaries are deliberately distributed through their own
reviewed paths.

### 3. Install the current Advanced Snapshot r38 app-only update

The current camera UI is a separate signed package pair. The safest path is
the packaged wrapper, which downloads the exact r38 tag, checks the release
key fingerprint, verifies both APK signatures and simulates by default:

```sh
pmos-install-advanced-snapshot
pmos-install-advanced-snapshot --apply
```

If the r48 helper is not installed, use the checked-out script instead:

```sh
./scripts/install-advanced-snapshot
./scripts/install-advanced-snapshot --apply
```

The first command is verification/simulation only. `--apply` changes only
`advanced-snapshot` and `advanced-snapshot-lang`; it does not change the native
libcamera/IPA generation, PipeWire SPA, kernel, firmware, Waydroid image,
boot slots or partitions and does not reboot. The wrapper retains the release
assets under its work directory. Set `PMOS_SNAPSHOT_WORK_DIR` or pass
`--work-dir` when those assets are also your rollback copy.

For the direct release procedure, exact r38 APK names, key fingerprint,
checksums and the app-only rollback command, see the [Advanced Snapshot
README](https://github.com/lolren/advanced-snapshot#installation-methods).

### 4. Build and install the current r49 helper from source

Use this when you need the newest wrapper/session-unit source before a new
published runtime release. Building is done on Alpine/postmarketOS with an
`abuild` key; the resulting package is noarch and does not contain device
firmware or native ARM camera libraries:

```sh
apk add alpine-sdk git python3
cd /path/to/oneplus6t-pmos-fixes
make test
cd packaging
abuild -d
```

The `make test` line is optional; the authoritative package test is run by the
`APKBUILD` check phase. If package dependencies are available in a full
postmarketOS build environment, `abuild -r` may be used instead of `abuild -d`.
`-d` skips only runtime dependency resolution for a pure Alpine builder; it
does not skip the Python bridge tests.

The reference r49 build was named
`oneplus6t-pmos-fixes-0.1.0_p20260831162331-r49.apk` and had SHA-256
`5f64915c0b99575730a3c31e401348c84ffd30fd90f9c5b7964812387de615d5`. A new
build can have a different source-date filename, so always use the checksum
produced for that exact build. Verify the package signature with the matching
public key from the same buildroot before installing:

```sh
sha256sum /path/to/oneplus6t-pmos-fixes-*.apk
apk --keys-dir /path/to/verified-buildroot-keys \
  verify /path/to/oneplus6t-pmos-fixes-*.apk
sudo apk add --simulate --upgrade --allow-untrusted \
  /path/to/oneplus6t-pmos-fixes-*.apk
sudo apk add --upgrade --allow-untrusted \
  /path/to/oneplus6t-pmos-fixes-*.apk
```

Do not use the release key to authenticate an unrelated local build, and do
not publish a private `abuild` key. After installation, run the read-only
health/status commands before enabling any optional service.

### 5. Recover SSH locally when the daemon is unhealthy

If USB networking answers ping but port 22 is unavailable, recover the
phone-side SSH service from its local terminal with the packaged helper:

```sh
sudo pmos-enable-ssh --apply
```

It supports both systemd and OpenRC, persists `sshd`, verifies the listener and
does not alter firewall rules. If port 22 and its banner work but authenticated
commands stall, use `sudo pmos-enable-ssh --apply --restart` locally to replace
the wedged daemon. The recovery procedure and direct fallback commands are in
[docs/TRANSPORT.md](docs/TRANSPORT.md).

The detailed release history for r44 and earlier is retained in the linked
release pages and [docs/VALIDATION.md](docs/VALIDATION.md). The current r48
runtime installation is documented above in Method 2.

The r38 app-only package and wrapper are documented above in Method 3. The
default native r35/r36 generation remains separate from that app update.

The complete native-generation wrapper and its pinned stage procedure are
documented below in Method 6.

### Current r49 source contents

The current checkout recipe is r49. It adds the signed r35/r36 camera-generation
manifest and its current public verification key alongside the guarded
synchronizer for the two Waydroid recording-profile files and the r35 temporary
sleep inhibitor,
and root-only shell diagnostic for the SSH-launched camera probe. Every
Waydroid status and shell operation is now bounded, and a stopped or still-
frozen container is rejected before a probe can hang against a torn-down LXC
session. The location bridge accepts both ModemManager key-value layouts with
signal-safe cleanup, and the NFC checker selects and restores the kernel-NCI
adapter during an explicit poll; none of these changes normal suspend behavior.
r45 additionally installs the disabled `oneplus6t-waydroid-session.service`,
which keeps the graphical Waydroid session in the greetd/Wayland system scope
instead of an SSH login scope. r42 also provides an explicit local `sshd`
restart path for an
authenticated-but-stalled SSH daemon. Build it from
`packaging/` as documented in [packaging/README.md](packaging/README.md), or
use the source checkout directly with `make install`.

### 6. Install the reviewed native camera generation

This is a larger, independently rollback-safe operation. It installs the
matching libcamera/IPA, PipeWire SPA and Advanced Snapshot generation together
from a signed offline stage. Use it when starting from a compatible base or
when deliberately changing the native camera lower layer; do not use it just
to obtain the r38 app-only autofocus fix.

The checked-in wrapper is pinned to the reviewed r35/r36 stage. It downloads
the release helper, stage archive, manifest, pmaports patch, public key and
release checksums over HTTPS. It simulates by default:

```sh
./scripts/install-camera-generation \
  --work-dir "$HOME/.cache/oneplus6t-camera-r35-r36"

./scripts/install-camera-generation \
  --work-dir "$HOME/.cache/oneplus6t-camera-r35-r36" \
  --apply
```

Before `--apply`, close every native and Android camera application, ensure
PipeWire and WirePlumber are healthy, run
`pmos-check-waydroid-health --status --processes`, and confirm there are no
Waydroid rootfs mounts, D-state helpers or current PSI I/O pressure. The
manager verifies the candidate and rollback APKs, repository indexes, package
hashes, current baseline, package-world change and exact solver transaction.
It retains the rollback stage and runs the bounded all-sensor smoke test after
an applied install. It does not reboot, touch fastboot/EDL, change partitions
or write firmware. The exact candidate/rollback procedure is in
[docs/CAMERA_GENERATIONS.md](docs/CAMERA_GENERATIONS.md), and the stage's
source/hash record is in [packaging/pmaports/README.md](packaging/pmaports/README.md).

The r35 native profiles apply the documented green-cast starting correction to
IMX371, IMX376 and IMX519. The app layer is still separate: after accepting the
lower stack, install r38 with `pmos-install-advanced-snapshot` and perform the
physical saved-photo checks before changing the default generation manifest.

### 7. Install the Google-free Waydroid camera layers

Waydroid is an optional Android 13 environment, not a prerequisite for native
postmarketOS cameras or mobile data. The supported default is a verified
Vanilla image without Google Play Services, Google Services Framework or Play
Store. Image creation, exact archive hashes and update policy are in
[docs/WAYDROID-VANILLA.md](docs/WAYDROID-VANILLA.md); optional GMS/GAPPS is a
separate procedure in [docs/WAYDROID-GAPPS.md](docs/WAYDROID-GAPPS.md).

Install in this order:

1. Initialize the official Vanilla image and run the read-only verifier
   `pmos-check-waydroid-vanilla`.
2. Stop both the graphical session and the container. Do not modify an active
   or stale-mounted rootfs.
3. Run `pmos-check-waydroid-health --status --processes` and require
   `overlay_precondition=pass`: rootfs mounts must be zero, both I/O-pressure
   classes must be clear and no D-state helper may be present.
4. Install the signed camera provider stage with
   `sudo scripts/install-waydroid-camera /path/to/camera-stage`. It backs up
   only its managed files and prints the exact rollback directory.
5. Install the separately built Codec2 stage with
   `sudo scripts/install-waydroid-v4l2-codec /path/to/codec-stage`. It also
   refuses mounted roots and active I/O pressure and prints its rollback path.
6. Synchronize the two image-level recording-profile files while Waydroid is
   still stopped. The synchronizer gives ordinary recording profiles only to
   rear-main camera ID 0 and fixed-focus front ID 1; auxiliary rear ID 2 keeps
   a framework sentinel and is not advertised for ordinary hardware video:

```sh
pmos-check-waydroid-health --status --processes
pmos-sync-waydroid-camera-profiles --dry-run
sudo pmos-sync-waydroid-camera-profiles
```

7. Log in to the normal graphical postmarketOS account. Only then enable the
   installed persistent session boundary:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now oneplus6t-waydroid-session.service
waydroid status
```

The unit waits for the normal user's Wayland/D-Bus session and avoids tying
Waydroid to an SSH login scope. It is installed disabled by design. The
current reference phone has the Vanilla/provider/Codec2 layers installed but
the session is stopped and the unit remains disabled while the phone is at the
greeter; this is a safety state, not a failed camera overlay.

The provider has passed all-camera YUV/JPEG/private preview probes, rear
tap/manual focus forwarding, EV changes and front-camera colour correction.
The guarded Codec2 path produces valid H.264/AAC recordings for rear-main ID 0
and front ID 1. Do not enable ordinary ID-2 video until the separate Venus
teardown/IRQ fault has a reviewed fix. For each overlay, retain the printed
backup and use the matching rollback command if validation fails:

```sh
sudo scripts/install-waydroid-camera --rollback /path/to/camera-backup
sudo scripts/install-waydroid-v4l2-codec --rollback /path/to/codec-backup
sudo pmos-sync-waydroid-camera-profiles --rollback /path/to/profile-backup
```

Do not enable the optional `oneplus6t-waydroid-location.service` merely to make
Waydroid start. It is a reversible mock-provider bridge for a fresh native
ModemManager fix, not a vendor Android GNSS HAL. Obtain a real outdoor native
fix first; the location procedure and cleanup guarantees are in
[docs/LOCATION.md](docs/LOCATION.md).

#### Earlier signed runtime releases

The following release notes are retained for reproducibility and rollback
archaeology. New installations should start with r48 (or a freshly built r49)
and the current procedures above.

The clean r47 package, which corrected the Waydroid recording-profile mapping
and includes the checksum-verified Advanced Snapshot r38 app-only installer,
is published in the
[`runtime-r47-video-profile-correction` release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r47-video-profile-correction).

The r47 profile correction assigns ordinary H.264/AAC recording profiles to
the live rear-main ID 0 and fixed-focus front ID 1, retains the parser-only ID
2 sentinel, and records a stopped-rootfs backup before changing either
profile file. The actual reference phone produced valid 720p H.264/AAC files
on both supported IDs after synchronization.

The clean r45 package is published separately in the
[`runtime-r45-waydroid-session` release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r45-waydroid-session).
It contains no kernel, firmware, bootloader or partition changes and leaves
the new session unit disabled until the administrator enables it after the
Waydroid health gate passes.

The clean r44 package built from the current checkout is published in the
`runtime-r44-camera-r35` pre-release; its exact SHA-256 is recorded in that
release's `SHA256SUMS`. It includes the lower-layer r35/r36 manifest and the
socket-activation-safe camera generation manager.

The clean r42 package built from commit `cb8f1e7` has SHA-256
`9b1677d6e733b90876e06a3c1958006072bb6670aab1e91baaa2e7903ed9eb50` and is
published in the pre-release above. It adds the explicit local `sshd` restart
fallback needed when TCP/22 and authentication work but the SSH session
channel is wedged.

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

### 8. Optional location bridge

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

### 9. Configure daily-use defaults

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
use the real IMX519/IMX376 actuator range; Advanced Snapshot r36 also reapplies
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
The banner is not an authenticated session test. The report labels this state
`ssh-transport-usable`; after it passes, use
`scripts/check-device-session` as documented in
[docs/TRANSPORT.md](docs/TRANSPORT.md) before installing packages.

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
| Tap-to-focus and truthful reticle | Maps a preview tap through crop/orientation into a real sensor metering region; the current r35 transport and Advanced Snapshot r38 correlate the result and use amber/green/red state. |
| Manual rear focus | Exposes `LensPosition` 0.0–2.0 in Advanced Snapshot; the simple IPA maps it to the bounded 400–800 actuator span and the fixed-focus front disables it. |
| Filtered two-pass GPU scaling | Removes the Bayer-phase grid while retaining the intended field of view and practical preview speed. |
| Exposure, colour, contrast and detail controls | Changes the software ISP through standard controls and affects preview and saved images. |
| Manual shutter and analogue gain | Disables automatic regulation and submits standard `ExposureTime` and `AnalogueGain` values in microseconds and linear gain units; the IPA clamps them to the active sensor. |
| Gamma and sensor calibration | Advanced Snapshot exposes a standard `Gamma` tone control plus a phone-width per-sensor calibration dialog for repeatable exposure, white balance, 3×3 colour matrix, contrast, detail and focus settings; profiles are keyed by stable camera identity. |
| Automatic/manual white balance | Keeps statistics-driven AWB as the default, transports standard red/blue `ColourGains` arrays through PipeWire and lets Advanced Snapshot persist bounded gains per physical sensor. |
| Writable colour correction | Exposes the standard nine-element `ColourCorrectionMatrix` on all three native cameras while white balance is manual; the r35 downstream profiles add a stronger, grey-preserving green-cast correction, while the app retains bounded user/chart overrides without claiming factory calibration. |
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
| Waydroid recording-profile synchronizer | `pmos-sync-waydroid-camera-profiles` repairs stale image-level `media_profiles*.xml` mappings so Android sees rear main ID 0 and front ID 1 for ordinary video; it keeps only a non-recording ID 2 framework sentinel, requires a stopped/unmounted Waydroid rootfs, records exact backups, and supports rollback. |
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
publishes the newer libcamera r35 / Advanced Snapshot r38 / PipeWire r8 line. The
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

The current source line is libcamera/IPA r35 and PipeWire SPA r8, with
Advanced Snapshot r38 installed as a separate app-only update. The r34
libcamera/IPA pair remains the exact lower-stack rollback and the r36 app pair
remains the lower-generation rollback. The app source is commit
`df308e9d95ba9d90ac6866010db3b95ce9d11de4`; the exact AArch64 package pair is
built, artifact-validated and live-tested. The controls panel and calibration dialog now
include automatic/manual white balance, per-sensor red/blue gains and a
bounded 3×3 colour matrix. The r35 IPA selects the documented sensor-specific
profiles and applies a stronger grey-preserving green-cast correction to
IMX371, IMX376 and IMX519; equal-channel test-pattern output remains neutral.
Controlled final frames reduced the rear green ratios from 1.304 to 1.238 and
from 1.256 to 1.181, while the front neutral-tile check remained stable at
approximately 1.062 versus 1.063. Custom matrix requests were accepted on all
three sensors, while automatic mode restored each stream. The 1.0× chip is
contained by the top toolbar and no
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
optionally restore a deliberate manual focus position. The r38 camera-page
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

For historical reproduction of the r7/r4-to-r7/r5 UI update, stage the unchanged r7
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
rolls back to the r7 Advanced Snapshot pair. It remains an explicit historical
opt-in; the default manager manifest is now r35/r36.

An opt-in r9 save-feedback candidate is available from the
[camera-r7-r7 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r7).
Use it with `data/camera-generation-r7-r7.psv`; it keeps PipeWire r7, upgrades
the app pair from r8 to r9 and rolls back to r8. The app now reports a visible
error when a capture produces no usable file. It remains an explicit historical
opt-in; the default manager manifest is now r35/r36.

An opt-in r10 adjustment-safety candidate is available from the
[camera-r7-r10 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r10).
Use it with `data/camera-generation-r7-r10.psv`; it keeps PipeWire r7, upgrades
the app pair from r9 to r10 and rolls back to r9. r10 cancels stale image-
adjustment helpers when a newer slider request, camera switch or page teardown
supersedes them. It remains an explicit historical opt-in; the default manager
manifest is now r35/r36.

An opt-in r11 bounded rear-flash candidate is available from the
[camera-r7-r11 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r11).
Use it with `data/camera-generation-r7-r11.psv`; it keeps PipeWire r7, upgrades
the Advanced Snapshot pair from r10 to r11 and retains r10 for rollback. The
app's Hardware flash switch launches the bounded `pmos-camera-flash` helper
only for rear stills and restores LED state on completion or interruption. It
remains an explicit historical opt-in; the default manager manifest is now
r35/r36.

The earlier opt-in lower-stack candidate is available from the
[camera-r26-r15 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r26-r15).
Use it with `data/camera-generation-r26-r15.psv`; it updates the matching
libcamera/IPA r26 pair and Advanced Snapshot r15 while retaining the exact
r24/r11 rollback stage. r15 aligns bounded whole-frame handheld translation
before its opt-in linear-light Software HDR merge. It remains source/package
validated and is retained for historical reproduction; the default manager
manifest is now r35/r36.

The current complete lower-stack generation is `data/camera-generation-r35-r36.psv`.
Its signed stage upgrades libcamera/IPA to r35, keeps PipeWire at r8 and
retains Advanced Snapshot r36; the exact r34/r36/r8 package set is retained
for rollback. Use the simulation-first procedure in
[docs/CAMERA_GENERATIONS.md](docs/CAMERA_GENERATIONS.md) and pass the explicit
manifest when the stage is downloaded. It contains the stronger
grey-preserving green-cast correction for all three sensors. It is live-tested
on the reference phone: rear green ratios fell from 1.304 to 1.238 and from
1.256 to 1.181 in the controlled final frames, and the all-sensor focus smoke
test passed with zero restarts during both 60-second rear windows.
The signed stage and runtime package are published in the
[runtime-r44/camera-r35 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/runtime-r44-camera-r35).

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

On installed Advanced Snapshot r38:

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

The sliders affect both preview and saved output. The Advanced Snapshot r38
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

## Project status and remaining work

The requirement-by-requirement audit is maintained in
[docs/STATUS-MATRIX.md](docs/STATUS-MATRIX.md), with sanitized command output
in [docs/VALIDATION.md](docs/VALIDATION.md). The short version is below, but
the distinction between “implemented”, “package-verified” and “physically
accepted” is important for every camera and hardware claim.

### Achieved

- A database-backed, carrier-neutral mobile-data setup chooses the official
  provider/APN record when it is unambiguous, understands SIM GID1, accepts a
  user-supplied officially documented APN for carriers absent from the
  database, and records only the managed connection UUID. SMARTY LTE routing,
  DNS, IPv4 and HTTPS were live-tested. The five-minute watchdog repairs the
  stale QMAP bearer case without cycling healthy profiles or interfering with
  voice calls.
- Network time, cellular-only fallback testing, provider diagnostics and safe
  profile removal are reproducible. The reference phone reported synchronized
  time in `Europe/London`; a bad clock is treated as a separate bootstrap
  problem rather than silently trusted.
- PipeWire/WirePlumber owns the native audio graph. The route policy selects
  top microphone plus speaker output for speakerphone, bottom microphone plus
  earpiece for ordinary calls, and headset microphone/output when a headset is
  present. Native capture, Waydroid AAC capture and physical-speaker playback
  pass the available non-call tests.
- The native camera generation exposes all three sensors, standard controls,
  rear AF/manual focus, automatic/manual WB and a repeatable green-cast
  starting profile. The current physical lower-layer baseline is kernel r10,
  libcamera/IPA r35 and PipeWire SPA r8.
- Advanced Snapshot r38 is a separate application and language package. Its
  live controls, phone-width calibration UI, green-cast action, tap reticle,
  rear manual focus, pinch zoom, full-resolution still path, fresh still-stream
  AF, software HDR and bounded flash integration are source/package validated.
  The exact release is linked in the installation section above.
- The Waydroid layer is Google-free by construction: Vanilla Android 13,
  Camera3 provider and Codec2 overlays are verified separately. All three
  camera IDs preview; ordinary video profiles are deliberately limited to
  rear-main ID 0 and fixed-focus front ID 1. Those two IDs produced valid
  H.264/AAC recordings in the validated probes. Android provider teardown,
  mixed RGB/NV12 processing, JPEG buffer sizing, fence synchronization and
  worker lifecycle are covered by the open overlays.
- The display diagnostic, kernel r10 recovery candidate, NFC report/poll
  cleanup, read-only location report, reversible Waydroid location bridge,
  battery sampler, five-minute suspend policy and camera-critical update guard
  all have fixture/source/package tests and retained rollback paths.
- The current source tree is reproducible and documented. The published r48
  noarch runtime is available for users; the current r49 source revision
  refreshes the r38 installer and graphical-session binding. The r49 local
  reference APK was
  `oneplus6t-pmos-fixes-0.1.0_p20260831162331-r49.apk` with SHA-256
  `5f64915c0b99575730a3c31e401348c84ffd30fd90f9c5b7964812387de615d5`.

### Remaining priority order

1. Log in to the normal graphical session and complete physical r38 tests:
   no-tap fresh autofocus, rear tap focus, manual focus, saved JPEG sharpness,
   camera switching, preview recovery and both rear modules. This is the next
   camera gate; a build or non-image probe cannot replace it.
2. Compare controlled grey-card/colour-chart images with Android. Measure
   white balance, exposure, sharpness, local contrast and green cast per sensor.
   Factory CCM, lens shading, temporal denoise, vendor HDR and proprietary
   Android ISP tuning remain unavailable and are not claimed.
3. Validate native video, Advanced Snapshot HDR, rear LED restoration, all
   visible controls and preview latency. Keep the r38 app-only rollback pair
   and the lower r34/r36/r8 generation until those tests pass.
4. Enable `oneplus6t-waydroid-session.service` only after the normal graphical
   account has a Wayland/D-Bus session and the health gate passes. Then test
   ordinary Android apps, camera-app open/close soaks, playback, microphone,
   speakerphone/earpiece routing and Maps. Main-rear video remains
   performance-limited; auxiliary rear ID 2 hardware encoding remains blocked
   after the reproducible Venus IRQ/teardown fault.
5. Obtain a fresh outdoor native GNSS fix before testing the reversible
   location bridge. The current no-coordinate result must not be replaced by a
   guessed Reading/Stroud coordinate. A vendor Android GNSS HAL/A-GPS path is
   still open.
6. Read a real NFC tag, repeat modem-call audio and display brightness/
   lock/suspend tests, and collect matched unplugged battery measurements.
   These are hardware acceptance gates, not assumptions from fixture tests.
7. Re-run a real-phone rollback and reboot-persistence test for each accepted
   package generation, then rebase camera-critical recipes against upstream
   postmarketOS only after the health gate, signatures, manifests and complete
   smoke tests pass.

### Current device gate

```text
USB: postmarketOS CDC-NCM developer networking; authenticated SSH was used for
     the r38 app-only and r49 helper deployments
Fastboot/ADB: not used or expected while the phone exposes the pMOS USB gadget
Kernel: r10 installed and booted on the OnePlus 6T
Native camera: libcamera/IPA r35, PipeWire SPA r8, Advanced Snapshot r38
Waydroid: Vanilla/provider/Codec2 layers installed; session STOPPED at greeter
           and persistent graphical-session unit deliberately disabled
Cellular: SMARTY LTE routing, DNS and HTTPS accepted; Wi-Fi restoration tested
Recovery: no raw partition, bootloader, EDL or firmware operation performed
```

The disabled Waydroid session is intentional until a normal graphical login
exists. It is not safe to infer Android application behavior from an SSH shell
or from a stopped container. Likewise, an empty `fastboot devices` result
while the running phone is in CDC-NCM mode is a transport distinction, not
evidence that the phone needs raw flashing.

## Upstream data sources

- [NetworkManager GSM settings](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/nm-settings-nmcli.html)
- [GNOME mobile-broadband-provider-info](https://gitlab.gnome.org/GNOME/mobile-broadband-provider-info)
- [SMARTY APN documentation](https://help.smarty.co.uk/en/articles/1155220-using-the-internet-after-you-ve-joined-smarty)
- [OnePlus 6T postmarketOS wiki](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29)

No device identifiers, account credentials, SIM serials, IMSIs, host keys or
unsanitized logs belong in this repository.
