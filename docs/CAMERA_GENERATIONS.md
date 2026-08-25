# Camera generation manager

`scripts/manage-camera-generation` is the guarded installer for the accepted
OnePlus 6T PipeWire r7 plus Advanced Snapshot r1 generation and its exact r6/r0
rollback. It is deliberately narrower than a general package updater.

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

## Stage layout

```text
camera-r7-r1/
├── candidate/
│   ├── aarch64/
│   │   ├── APKINDEX.tar.gz
│   │   ├── advanced-snapshot-0.1.0-r1.apk
│   │   └── pipewire-spa-libcamera-1.6.8-r7.apk
│   └── noarch/
│       └── advanced-snapshot-lang-0.1.0-r1.apk
└── rollback/
    ├── aarch64/
    │   ├── APKINDEX.tar.gz
    │   ├── advanced-snapshot-0.1.0-r0.apk
    │   └── pipewire-spa-libcamera-1.6.8-r6.apk
    └── noarch/
        └── advanced-snapshot-lang-0.1.0-r0.apk
```

Each repository must contain exactly its three APKs. Extra APK files are a
hard failure, preventing dependency resolution from silently selecting an
unreviewed build.

## Check and simulate

Show the installed generation without a stage directory:

```sh
./scripts/manage-camera-generation status
```

Verify the device, public key, six package hashes, six signatures, repository
contents and exact apk transaction, without changing installed state:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r1 \
  install
```

Simulation is the default. The command requires exactly three upgrades and
proves both the package versions and `/etc/apk/world` are unchanged afterward.
All logs and trust hashes are written to a new dated directory under
`STAGE/evidence/`; use `--evidence EMPTY_DIR` to choose another location.

## Apply

Run as the graphical login user, not root:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r1 \
  --apply install
```

`--apply` repeats all preflight checks and the simulation. It refuses a mixed
package state or an active camera/GStreamer client, stops the main desktop
portal and its wlroots backend before PipeWire, performs only the three audited
upgrades, restores services, checks that only the two app identity lines
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
  --stage /absolute/path/to/camera-r7-r1 \
  rollback
```

Apply only after that simulation lists the three expected downgrades:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r1 \
  --apply rollback
```

The local r6 PipeWire file temporarily creates a world identity constraint.
The manager simulates removing that constraint, requires installed reverse
dependencies to retain the plugin, removes only the constraint, then verifies
r6/r0 and runs the compatibility-mode all-sensor test. It never replaces the
whole world file.

## Refusal conditions

The manager stops before mutation for a wrong device, wrong or missing key,
bad package hash/signature, missing or extra APK, missing index, mixed package
versions, unexpected install/remove operation, simulation side effect, active
camera client, unavailable media service or root `--apply`. After mutation it
rejects an unrelated world-file change, a missing service, wrong final version
or failed camera smoke test and preserves the complete evidence directory for
manual diagnosis and the verified rollback.

This manager does not yet replace the future VibeMarketOS signed repository or
block arbitrary distro upgrades. That updater will use the same manifest and
health gate before activating camera-critical postmarketOS updates.

## Validation

The host-side suite covers simulation, applied install, applied rollback,
dependency-preserving PipeWire unpin, mixed-generation refusal, unexpected apk
operations, a repository-index race and tampered packages. `make test` passes
all manager, APN, Messages and image-metric tests.

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
