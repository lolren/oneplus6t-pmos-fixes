# Waydroid camera support

This document covers the open-source Camera3 path used by Android 13 in
Waydroid on the OnePlus 6T. It uses the mainline kernel cameras and libcamera's
software ISP. It does not copy OnePlus/OxygenOS camera libraries, calibration
blobs or firmware.

The reference phone runs Waydroid 1.6.3 with an ARMv7 mainline vendor image.
The r35 overlay is installed and exposes three Android cameras. It includes
the Mesa EGL software-ISP path, a DMA-heap allocator fallback and the
Camera3 logical-JPEG-size fix. The native postmarketOS stack is packaged
separately; see [CAMERA.md](CAMERA.md).

## Features and their benefit

| Feature | What it brings |
| --- | --- |
| Three-camera enumeration | Android applications can open the main rear, secondary rear and front sensors instead of seeing no camera provider. |
| Camera location and rotation map | Camera2 receives the correct front/back role and display orientation for each stable media path. |
| minigbm plane parsing | The HAL reads Waydroid's real buffer offsets, strides and sizes, preventing corrupt mappings and one-plane assumptions. |
| Software NV12 output | The mainline software ISP can fill Android YUV and implementation-defined preview buffers without a proprietary ISP HAL. |
| Mesa EGL/libyuv software ISP | Converts the validated Android preview path through the phone's Mesa GPU stack instead of the much slower CPU-only conversion. `mode: gpu` is recorded in the runtime configuration. |
| DMA-heap internal buffers | Falls back to CMA/system DMA heaps when the mainline image does not provide the legacy Android gralloc allocator. |
| YUV, JPEG and private streams | Preview, analysis and still-capture paths used by ordinary Camera2 applications all return data. |
| Logical JPEG BLOB sizing | Places the Camera3 JPEG footer at the logical buffer end expected by Android even when minigbm aligns the physical plane. |
| Valid low-frame-rate metadata | A camera whose usable mode is below 30 fps remains in Android's stream map instead of causing malformed Camera2 characteristics. |
| Variable 15–30 fps preview | In low light, applications may allow a frame to grow to about 66.7 ms for more exposure; a fixed 30 fps video request stays fixed. |
| Reduced large preview source | For aspect-preserving 1600-wide private/YUV previews, the software ISP can debayer a supported 1280-wide source and scale into Android's requested buffer; JPEG capture remains full-size. |
| Exposure compensation | Camera2 -1 to +1 EV requests reach libcamera and the applied value returns in capture results. |
| Exposure result metadata | Exposure time, sensor sensitivity and frame duration let applications understand what automatic exposure actually selected. |
| Rear autofocus bridge | Camera2 auto/continuous modes, triggers, states and one metering region reach both physical rear actuators. |
| Bounded explicit focus scan | Tap-focus does not spend hundreds of frames traversing the entire actuator range; it uses a fast bounded scan and local refinement. |
| Fixed-focus reporting | The front camera honestly advertises no autofocus instead of accepting controls that cannot move hardware. |
| SIGPIPE-safe IPA teardown | A closed software-IPA Unix socket returns `EPIPE` through libcamera's existing error path instead of killing the Android provider with signal 13. |
| Automated Camera2 probe | A reproducible APK verifies every stream, AF state and exposure path without depending on a store camera application. |

These are lower-layer camera features. They do not add a polished Android
camera UI by themselves; an Android camera application consumes them.

## Source layout

- `patches/libcamera/v0.7.2/` contains the sixteen generic native patches. The
  final two add `FrameDurationLimits` and stable progressive autofocus
  transitions to simple-pipeline sensors.
- `patches/libcamera/waydroid/v0.7.2/` contains the Android-only Camera3 HAL
  series. Apply `0001` first, followed by the libyuv conversion, Mesa GPU
  software-ISP, robust DMA/JPEG, SIGPIPE-safe IPC and reduced-preview-source
  patches (`0002`–`0006`).
- `config/waydroid/camera_hal.yaml` maps stable OnePlus media paths to Android
  facing and rotation values.
- `config/waydroid/configuration.yaml` selects GPU software-ISP mode, preserves
  the input buffer and limits the soft-ISP worker count.
- `config/waydroid/init.zz-oneplus6t-camera.rc.in` is the provider override.
  Its `@VIDEO_GID@` placeholder must become the numeric postmarketOS `video`
  GID; the `zz` prefix makes the ordering explicit.
- `scripts/build-waydroid-camera` creates a clean Android ARMv7 libcamera build
  and runtime staging tree.
- `scripts/package-waydroid-camera` creates a tarball and matching file
  manifest from a staging tree.
- `scripts/install-waydroid-camera` performs a target-scoped backup, install
  and rollback without touching partitions or firmware. Before any backup it
  refuses to access the overlay if a `/var/lib/waydroid/rootfs` mount remains;
  this prevents a stale lowerdir mount from turning a copy into an
  uninterruptible I/O wait.
- `tests/waydroid-camera-probe/` builds the validation APK.

The Android series depends on the generic frame-duration and autofocus work. It
is intentionally separate from pmaports because Android HAL code and its ABI
dependencies do not belong in the native Alpine package.

## Build requirements

The tested host was x86-64 Linux with:

- Git, Meson 1.12.0, Ninja, CMake, pkg-config, Python 3 plus PyYAML and OpenSSL;
- Android NDK `29.0.14206865` targeting ARMv7 API 33;
- a static ARMv7 Android dependency prefix containing:
  - OpenSSL/libcrypto 3.5.7;
  - libexif 0.6.26, commit
    `b2edc5a8adf4d1b79ce9413a9c9d8f3ab871c082`;
  - libjpeg-turbo 3.2.0, commit
    `c85e6b905bf237038faa936dab160ebfc5da0344`; and
  - libyuv commit `500f45652c459cfccd20f83f297eb66cb7b015cb`;
- enough space for a clean libcamera build; and
- network access for Meson's pinned libyaml fallback, unless that wrap is
  already cached.

The prefix must contain headers, static libraries and pkg-config files under
`include/`, `lib/` and `lib/pkgconfig/`. The build helper checks every required
compiler and library and refuses a non-empty build or stage directory. It does
not silently link x86 host libraries into the ARM build.

The runtime phone must have:

- OnePlus 6T postmarketOS edge with the documented SDM845 camera kernel stack;
- Waydroid 1.6.3 or a reviewed compatible version;
- an Android 13 ARMv7 mainline image;
- `/vendor/bin/hw/android.hardware.camera.provider@2.4-service`; and
- root access for the overlay installation.

Do not install these ARMv7 Android libraries into native `/usr/lib`.

## Prepare the source

Apply the pmaports integration patch first. Its resulting libcamera recipe
contains the two postmarketOS base patches and this project's sixteen generic
patches. Apply that sequence to a clean libcamera 0.7.2 source tree, then apply
the six Android patches in numeric order:

```sh
git clone https://gitlab.freedesktop.org/camera/libcamera.git libcamera-waydroid
cd libcamera-waydroid
git checkout v0.7.2

git am /path/to/patched-pmaports/temp/libcamera/0001-*.patch
git am /path/to/patched-pmaports/temp/libcamera/0002-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/v0.7.2/*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0001-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0002-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0003-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0004-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0005-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0006-*.patch
```

Stop if any patch rejects. Do not use `--3way` to hide a source-version
mismatch. The reviewed order ends with generic frame duration, generic
autofocus-transition stability, the Android Camera3 HAL, GPU NV12 conversion,
robust buffer/JPEG handling, SIGPIPE-safe IPA socket teardown and the
aspect-preserving reduced preview source. The fifth patch is deliberately
small: it changes only the two libcamera IPC send calls that can otherwise
deliver SIGPIPE after an IPA peer closes. The sixth patch is a performance
candidate and must be accepted on the phone before it is treated as a runtime
baseline.

## Build a runtime bundle

Choose new, empty build and stage directories:

```sh
export ANDROID_NDK_ROOT=/path/to/Android/Sdk/ndk/29.0.14206865
export WAYDROID_DEPS_PREFIX=/path/to/android-armv7-dependencies
export ANDROID_API=33
export WAYDROID_SOFTISP_GPU=enabled

/path/to/oneplus6t-pmos-fixes/scripts/build-waydroid-camera \
  /path/to/libcamera-waydroid \
  /path/to/build-waydroid-camera \
  /path/to/stage-waydroid-camera

/path/to/oneplus6t-pmos-fixes/scripts/package-waydroid-camera \
  /path/to/stage-waydroid-camera \
  /path/to/waydroid-camera-r35-gpu
```

The helper configures only the simple pipeline/IPA and generic Android HAL,
builds for ARMv7, signs the IPA with the build-local key, installs under the
staging `vendor/` tree, adds `libc++_shared.so`, and installs the reviewed
OnePlus tuning, camera map and GPU configuration. `enabled` selects the
validated Mesa path; `auto` lets Meson choose and `disabled` is a CPU-only
fallback for diagnosis. The generated IPA private key remains in the build
directory and must not be committed. Build and stage directories must be new
or empty; this prevents mixing signed IPAs or libraries from different builds.

At minimum, retain these runtime files together:

```text
vendor/etc/libcamera/camera_hal.yaml
vendor/etc/libcamera/configuration.yaml
vendor/lib/hw/camera.libcamera.so
vendor/lib/libcamera.so
vendor/lib/libcamera-base.so
vendor/lib/libc++_shared.so
vendor/lib/libcamera/ipa/ipa_soft_simple.so
vendor/lib/libcamera/ipa/ipa_soft_simple.so.sign
vendor/libexec/libcamera/soft_ipa_proxy
vendor/share/libcamera/ipa/simple/imx371.yaml
vendor/share/libcamera/ipa/simple/imx376.yaml
vendor/share/libcamera/ipa/simple/imx519.yaml
vendor/share/libcamera/ipa/simple/uncalibrated.yaml
```

Do not mix a HAL from one build with a library or signed IPA from another.

## Install into the Waydroid overlay

### Preflight

Before stopping services or opening the overlay, collect the read-only
preflight report:

```sh
pmos-check-waydroid-health --status \
  --output /private/path/oneplus6t-waydroid-health.txt
```

Proceed only when the report contains:

```text
rootfs_mounts=0
overlay_precondition=pass
```

The check also records `/proc/loadavg` and `/proc/pressure/io`. It does not
stop Waydroid, unmount anything, kill a process or write the overlay. If a
rootfs mount remains or storage I/O is pressured, recover the phone and repeat
the report before using the installer. The installer independently rechecks
`/proc/self/mountinfo` and refuses a mounted rootfs.

The package helper produces a tarball and a manifest. Extract the tarball into
a fresh staging directory, then use the installer so the provider GID is
resolved on the target phone and every managed target is backed up before it is
replaced:

```sh
mkdir -p /tmp/waydroid-camera-r35-gpu
tar -xzf /path/to/waydroid-camera-r35-gpu.tar.gz \
  -C /tmp/waydroid-camera-r35-gpu

sudo scripts/install-waydroid-camera --dry-run \
  /tmp/waydroid-camera-r35-gpu
```

Stop only Waydroid after reviewing the dry run, then install:

```sh
waydroid session stop
sudo waydroid container stop
sudo scripts/install-waydroid-camera \
  /tmp/waydroid-camera-r35-gpu
```

The installer manages the 13 runtime files plus
`system/etc/init/init.zz-oneplus6t-camera.rc`. It creates a dated backup under
`/var/lib/waydroid/backups/` and prints its path. Set
`WAYDROID_CAMERA_BACKUP_ROOT` to use another backup root. Shared objects, YAML
and the signature are mode 0644; the software-IPA proxy is mode 0755. The
provider override runs as Android's `cameraserver`, adds the host video GID so
it can open the mainline media devices, and writes bounded diagnostic logs to
`/data/local/tmp/libcamera-provider.log` inside Android.

Start the container as root and the session as the normal login user:

```sh
sudo waydroid container start
waydroid session start
```

This operation does not alter a partition, boot slot, kernel or firmware and
does not require a phone reboot. The installer does not start or stop services;
that is kept explicit so it cannot unexpectedly interrupt a camera session.

The installer reads `/proc/self/mountinfo` before both installation and
rollback. If Waydroid's rootfs or one of its child mounts is still present, it
fails immediately with the mount path. `WAYDROID_ROOTFS_DIR` and
`WAYDROID_CAMERA_MOUNTINFO` are available for a nonstandard layout or test
fixture. Do not bypass this check while the rootfs is mounted: the overlay is a
lower directory of that rootfs, and copying its files can deadlock the storage
path.

## Verify

Confirm Android is ready and that the provider reports three devices:

```sh
waydroid status
sudo waydroid shell dumpsys media.camera
```

Then build and run the probe as documented in
`tests/waydroid-camera-probe/README.md`. A complete reference run ended with:

```text
PROBE_DONE valid=3 total=3
```

The current probe revision deliberately requests a large implementation-
defined preview when the device advertises one, preferring 1600x1200 and then
1920x1080. Each `CAMERA` record reports `privateSize`, `privateFps` and
`privateIntervalMs`; these values make the reduced-source candidate measurable
against the previous bundle. They measure frames delivered to Camera2, not
display latency, and are diagnostic fields rather than pass/fail thresholds.

The final r35 run on 25 August 2026 verified all three YUV/JPEG/private stream
sets. Camera 0 reported rear autofocus states `[3, 4]`, camera 2 reported
`[3, 5]`, and the fixed-focus front camera reported `[0]`. All cameras
returned -1/0/+1 EV metadata and visible pixel movement. A clean Aperture
capture produced a valid Exif JPEG at 1600x1200 with no
`fixUpHidlJpegBlobHeader` or `Image_getBlobSize` warning. Generated photographs
remain private and are not part of the repository.

The reproducible r35 GPU bundle is:

| Artifact | SHA-256 |
| --- | --- |
| `waydroid-camera-r35-gpu-final.tar.gz` | `6d1f03878991825d0dd0edfce5f98b9825dfd9e15f2aae59ad0fcde1ed4c8f6f` |
| `waydroid-camera-r35-gpu-final.sha256` | `2ff519dcf00bc09ebecb575260f88998f83e76fb1e6ff5cd3c9b8640b3a93b7a` |

Current r35 runtime hashes from that bundle are:

| File | SHA-256 |
| --- | --- |
| rendered `init.zz-oneplus6t-camera.rc` (video GID 27) | `872ddc99936135b0865d3f2fbc89d8d4ad7f4c06f63bceed75d2dd1ccd27ae05` |
| `camera.libcamera.so` | `2bb84d7bce0e1cefffd5ccb171bfbebb3a9bb752a13e60f422e2ed66ace105db` |
| `libcamera.so` | `418cbea4a985ddd45ea8475c2dfdf8d569c35a256164f5ccb667b299fb325077` |
| `libcamera-base.so` | `8b7e553e07ec651e17c231b2c35a27cd66fa9552d80e1d5eb0ce51bef8a0967a` |
| `libc++_shared.so` | `7ce65fd0fdd49236bc2ee618f6968dbb3fca46445f563f2bb4c994878853e` |
| `ipa_soft_simple.so` | `fea5c0662bb580f04ca26aed51780883367363ab29a732b593a084077dccbe14` |
| `ipa_soft_simple.so.sign` | `d4553fb5dbe02ea5e8fc415107bd6510279bbe4ba00c918a5a37f7c37aa554c0` |
| `soft_ipa_proxy` | `d521e909e7259624076ef838a8244a6a881f91f78d6985701303325d81328e3f` |
| `camera_hal.yaml` | `559eeec4df67ea5b2f884a28de312ea25b34d89789d570f2ae3a86266882fa65` |
| `configuration.yaml` | `1d7c6962e4af26831b2752e4ec683db16c05b95bbeb535127eaf97ae5fae50cc` |
| `imx371.yaml` | `7369cbd1fb61371bd0462ce71e51d10b37c85f05c41c6184aeca517ca03388a3` |
| `imx376.yaml` | `85bb26e2b6eeda694290d8da1ca100f2c1f5b33f3fd8e518ae7f523226b33551` |
| `imx519.yaml` | `b8a876520db79d059a3ff01576d0db2161a86c8ce50be25605976704b78ec473` |
| `uncalibrated.yaml` | `0689579ca79036bbd31d104deafca70fb8b267c4c8f8492e07bd6f6e875ee1ac` |

Historical r24 runtime hashes follow for rollback comparison:

| File | SHA-256 |
| --- | --- |
| rendered `init.oneplus6t-camera.rc` (video GID 27) | `f7a52425dcde9996b4119ab1115e9f6df0550cf0890f8e9f9a3987848e4ed733` |
| `camera.libcamera.so` | `650b18b57db4fbd46441b6cfb443b8275c51c8cfc4c910eacb990407a48b42b9` |
| `libcamera.so` | `6be47c42f61bea0e2b33439cbc290ab1544ccfb1e2dbd2f331b4031f4cde5002` |
| `libcamera-base.so` | `ab80f590a78ea6d830e7ef34fe642850c2304d2da342537e7d8807e7947b7fb0` |
| `libc++_shared.so` | `7ce65fd0fdd49236bc2ee618f6968dbb3fca46434845f563f2bb4c994878853e` |
| `ipa_soft_simple.so` | `aa3fcebbf124643a4a0c281c7206f6544249f2415bf468d2aa94a64f82e7b24a` |
| `ipa_soft_simple.so.sign` | `38f32fc98445b32f7f61e1daf16fc211aa11faf6d7e8a17369c52fd9d57ce3df` |

The signature changes when a new build-local IPA key is generated, so hashes
are reference evidence rather than a substitute for source verification.
The installer renders the provider fragment with the target's actual video
GID, stores a presence manifest and SHA-256 list in a dated rollback tree, and
does not overwrite unrelated overlay files. The r35 deployment retained
supplementary GID 27 and completed a container/session restart. The clean
probe ended with:

```text
PROBE_DONE valid=3 total=3
```

The probe passed YUV, private preview, JPEG, EV and sensor-timing checks for
all three cameras. Run it from a clean camera state: if Aperture still owns
the CAMSS media device, the probe can report a transient busy link rather than
a camera regression.

## Large-preview performance candidate

Android applications commonly request a 1600x1200 private/YUV preview even
when the display shows a smaller image. The software ISP still has to debayer
that complete source frame. Patch `0006` selects 1280x960 for a 4:3 request or
1280x720 for a 16:9 request when the corresponding source is smaller and
supported. The YUV post-processor then performs ratio-preserving scaling into
the original Android buffer. JPEG streams are not reduced, so still capture
keeps its requested resolution.

This is a performance trade-off, not an image-quality claim. It compiles and
applies cleanly, but the phone was not healthy enough for runtime acceptance:
the existing Waydroid rootfs remained mounted and storage I/O was stuck in an
uninterruptible wait. Do not install the candidate until a physical reboot has
cleared that state.

The ARMv7 GPU candidate was built with all 197 compile targets and the final
install/signature pass:

```text
patch 0006: a4f892e19efdf6fc3fac89518689d63eb2ba1bcf4ee7b68a069119184b06b987
waydroid-camera-preview-r35-gpu.tar.gz: 617a3bfc56fa41becaae4c14d75aca55ab4914ef745e75449f83448ee749f9ea
waydroid-camera-preview-r35-gpu.sha256: f5dd6bfe15f26ff8750fdd8ffc2a22061514339cf3527735f091fb95ba14c186
camera.libcamera.so: cff49eaebd2bed49f52197dafd417809fcb06936810e392b5c161a196fbb04eb
libcamera.so: fe9cb65b022b343d6236e99390114b386077649d40321096c7dc80f61048dca0
libcamera-base.so: 25582a0706149783c8a768d49f8dea45b05a1c6d7d856cb62ede8a99754356ec
ipa_soft_simple.so: fe9877e1841f5f4b7debbee72b24a1aa51607f6437ffc1bb5429befb9b846816
soft_ipa_proxy: 91a1d0f276586fc46099bb0c44cfd0f5355ea03a10df2addc72b563c64a982be
```

After reboot, verify there are no `/var/lib/waydroid/rootfs` mounts, run the
installer dry-run, install this exact bundle, then repeat the Camera2 probe
and compare preview frame timing against the r35 baseline. Roll back if
preview buffers, JPEG capture or provider stability regress.

## Rollback

Stop the Waydroid session and container, then pass the exact backup directory
printed by the installer to the rollback command:

```sh
sudo scripts/install-waydroid-camera --rollback \
  /var/lib/waydroid/backups/camera-YYYYMMDDTHHMMSSZ-PID
sudo waydroid container start
waydroid session start
```

The script restores every backed-up file to its original relative overlay path
and removes only targets explicitly recorded as absent before installation.
Require the prior camera count and provider state after restarting.

Never replace the complete Waydroid overlay with an old copy: it may contain
unrelated user changes. Never restore only the HAL while leaving a mismatched
libcamera or IPA in place.

## Known limits

- This is not OxygenOS image-quality parity. There is no calibrated CCM or
  lens-shading map, temporal denoise, multi-frame HDR, face processing or
  vendor scene tuning.
- The front camera has no physical focus actuator.
- Very dark scenes remain noisy even though a client can request a slower
  frame duration.
- The r35 lower layer has a clean JPEG-footer path in the accepted Aperture
  capture. Broader third-party-app and lifecycle testing is still required.
- Running the probe while Aperture or another camera client owns CAMSS can
  produce a transient media-link-busy result; stop camera clients and rerun the
  probe before treating it as a regression.
- Camera2 numeric IDs are provider enumeration details; applications should
  use facing/characteristics rather than assuming a fixed number.
- Play Store installation, GPS and the Waydroid location bridge are separate
  roadmap items. They are not claimed by this camera patch.
