# Camera generation manager

`scripts/manage-camera-generation` is the guarded installer for the current
OnePlus 6T PipeWire r7 plus Advanced Snapshot r7 generation and its exact r7/r4
rollback. It is deliberately narrower than a general package updater. The
legacy `camera-generation-r7-r1.psv` remains available for the earlier
r6/r0-to-r7/r1 lower-stack transition; the default manifest is r7/r5. The
opt-in r7/r7 manifest carries the r9 save-feedback app pair and r8 rollback;
the newer opt-in r7/r10 manifest carries the r10 adjustment-serialization pair
and r9 rollback.

## Requirements

- OnePlus 6T device-tree compatibility `oneplus,fajita`;
- postmarketOS with apk-tools 3, systemd user services, PipeWire and
  WirePlumber;
- the graphical login user with working `sudo` for apk transactions;
- all six exact APKs and both offline repository indexes; and
- a detailed object near the centre of the camera view for the post-install
  autofocus test.

The bundled manifest pins every package filename, version and SHA-256 plus the
SHA-256 of the public signing key. The public key is kept under
`packaging/keys/`; no private signing key is present or required.

## Latest opt-in candidate

`data/camera-generation-r7-r6.psv` describes the newly built capture-safety
candidate. It keeps `pipewire-spa-libcamera` at r7, upgrades Advanced Snapshot
and its language package from r7 to r8, and retains the exact r7 pair for
rollback. The matching development stage is published as the
[`camera-r7-r6` prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r6).

This candidate adds capture-output validation, safe zoom handling for unusable
camera limits and a harmless fallback for unknown orientation values. It passed
the clean AArch64 build and package validator but remains source-only until the
phone's transport and hardware health gates reopen. Use the explicit manifest
when reviewing it:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r6 \
  --manifest data/camera-generation-r7-r6.psv \
  install
```

The default remains `camera-generation-r7-r5.psv` until this candidate has been
accepted on hardware.

`data/camera-generation-r7-r7.psv` is the next opt-in UI-only candidate. It
keeps PipeWire r7 unchanged, upgrades Advanced Snapshot from r8 to r9 and
retains the exact r8 application pair for rollback. r9 reports a visible
`Could not save photo` toast when the capture pipeline returns no usable file;
it does not alter the camera kernel, libcamera, PipeWire or Waydroid stack. The
matching development stage is published as the `camera-r7-r7` prerelease.
The clean AArch64 package build and validator pass, but hardware preview and
save acceptance remain blocked by the current phone transport gate.

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r7 \
  --manifest data/camera-generation-r7-r7.psv \
  install
```

`data/camera-generation-r7-r10.psv` is the newest opt-in userspace candidate.
It keeps PipeWire r7 unchanged, upgrades Advanced Snapshot and its language
package from r9 to r10, and retains the exact r9 pair for rollback. r10
serializes and cancels image-adjustment helper processes, so rapid Exposure,
Colour, Contrast or Detail changes cannot leave stale helpers applying old
values after a newer request, camera switch, page teardown or stream stop. The
matching signed AArch64 stage is published as the
[`camera-r7-r10` prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r10).
The archive SHA-256 is
`b6f8e692c8e8fa59b749b2cb8c9c1ed0e92e14e27bbe99dd7fe948c6db29e5c5`.
It passed source/package validation but remains uninstalled until the phone's
transport and physical camera gates reopen.

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r10 \
  --manifest data/camera-generation-r7-r10.psv \
  install
```

## Stage layout

```text
camera-r7-r5/
├── candidate/
│   ├── aarch64/
│   │   ├── APKINDEX.tar.gz
│   │   ├── advanced-snapshot-0.1.0-r7.apk
│   │   └── pipewire-spa-libcamera-1.6.8-r7.apk
│   └── noarch/
│       └── advanced-snapshot-lang-0.1.0-r7.apk
└── rollback/
    ├── aarch64/
    │   ├── APKINDEX.tar.gz
    │   ├── advanced-snapshot-0.1.0-r4.apk
    │   └── pipewire-spa-libcamera-1.6.8-r7.apk
    └── noarch/
        └── advanced-snapshot-lang-0.1.0-r4.apk
```

Each repository must contain exactly its three APKs. Extra APK files are a
hard failure, preventing dependency resolution from silently selecting an
unreviewed build.

A matching development AArch64 stage can be downloaded from the
[camera-r7-r5 prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r5).
Verify `SHA256SUMS` before extraction. The archive is signed with the
development verification key bundled in this repository; it is a reproducible
development artifact, not a production repository.

## Check and simulate

Show the installed generation without a stage directory:

```sh
./scripts/manage-camera-generation status
```

Verify the device, public key, six package hashes, six signatures, repository
contents and exact apk transaction, without changing installed state:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r5 \
  install
```

Simulation is the default. The current manifest requires exactly the two r4-to-r7
app upgrades while proving that PipeWire remains at r7 and that both package
versions and `/etc/apk/world` are unchanged afterward. It also verifies both
offline repository-index signatures before invoking apk.
All logs and trust hashes are written to a new dated directory under
`STAGE/evidence/`; use `--evidence EMPTY_DIR` to choose another location.

## Apply

Run as the graphical login user, not root:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r5 \
  --apply install
```

`--apply` repeats all preflight checks and the simulation. It refuses a mixed
package state or an active camera/GStreamer client, stops the main desktop
portal and its wlroots backend before PipeWire, performs only the manifest's
two audited app upgrades, restores services, checks that only the two app identity lines
changed in `/etc/apk/world`, and runs the all-sensor non-image test. Both rear
cameras must report a
generation-correlated `focused` result; the fixed-focus front must stream and
reject focus as unsupported.

The script does not automatically reinterpret a low-detail `failed` result as
success. Stage a detailed central target and inspect the retained evidence.

## Rollback

Preview the exact reverse transition first:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r5 \
  rollback
```

Apply only after that simulation lists the two expected app downgrades:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r5 \
  --apply rollback
```

The current rollback changes only r7 to r4 and leaves PipeWire r7 untouched,
so it creates no PipeWire world identity and performs no unpin transaction.
When the legacy r7/r1 manifest changes PipeWire to r6, the manager still
simulates removing the temporary identity constraint, requires installed
reverse dependencies to retain the plugin, and removes only that constraint.
It never replaces the whole world file.

## Refusal conditions

The manager stops before mutation for a wrong device, wrong or missing key,
bad package hash/signature, bad repository-index signature, missing or extra APK,
missing index, mixed package versions, unexpected install/remove operation,
simulation side effect, active
camera client, unavailable media service or root `--apply`. After mutation it
rejects an unrelated world-file change, a missing service, wrong final version
or failed camera smoke test and preserves the complete evidence directory for
manual diagnosis and the verified rollback.

This manager is still not a replacement for the future VibeMarketOS signed
repository. The packaged `pmos-safe-upgrade` wrapper now blocks ordinary
distro upgrades that mention camera-critical packages; those packages must
come through this manager. A future signed repository will add compatibility-
gated published generations and retained public rollback artifacts rather than
relying on the wrapper's transaction-text gate alone.

## Validation

The host-side suite covers both two-transition static-PipeWire and
three-transition lower-stack generations: simulation, applied install, applied
rollback, dependency-preserving PipeWire unpin, mixed-generation refusal,
unexpected apk operations, a repository-index race and tampered packages.
`make test` passes all manager, APN, Messages and image-metric tests.

On the reference phone, the manager identified the live r7/r1 generation and
world SHA-256
`d032cb41e42bda904382159b10198e5c2dd9b73cda58d3f0060993756388e276`.
Its real apk-tools 3 rollback simulation verified all six signatures and
proposed exactly three downgrades. Package versions and the world file were
byte-identical afterward; the simulation log SHA-256 is
`80ed193f2cda1948189513281e51df615b7ab19a62efa9bd8d71b90fb39fbad9`.

The final service-choreography regression exercised all four portal/PipeWire
cycles on hardware. Both rear helpers returned `focused`, the front completed
120 frames with `unsupported`, and the 10-second stability summary SHA-256 is
`aa5d5dedf5834e90ac15bd121a3711b4a7c004df0b5f41a59f155e6013fb9260`.
The portal journal SHA-256 is
`9447840432b47360053b37dd960f988994808428223dcd2a25127773a595b201`;
it contains only orderly stop/start events and no fatal, failed or coredump
event. PipeWire, WirePlumber and both portal units ended active with zero failed
user units, no test environment and no camera process.
