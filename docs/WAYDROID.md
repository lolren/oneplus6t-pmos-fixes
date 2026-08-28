# Waydroid camera support

This document covers the open-source Camera3 path used by Android 13 in
Waydroid on the OnePlus 6T. It uses the mainline kernel cameras and libcamera's
software ISP. It does not copy OnePlus/OxygenOS camera libraries, calibration
blobs or firmware.

The reference phone runs Waydroid 1.6.3 with an ARMv7 mainline vendor image.
The installed r44 camera overlay exposes three Android cameras and retains the
Mesa EGL software ISP, DMA-heap fallback, JPEG sizing and r36 NV12 colour fix.
Patches `0013`–`0015` add multi-output processing, retain a fast linear RGB
preview beside coalesced NV12 consumers and cap private previews to a sensor
mode suitable for video. A separate Android 13 arm64 Codec2 service uses the
SDM845 Venus encoder while preserving Android's software encoder as fallback.
Aperture now configures simultaneous preview and encoder streams and saves
playable H.264/AAC video. The native postmarketOS stack remains separate in
[CAMERA.md](CAMERA.md).

## Features and their benefit

| Feature | What it brings |
| --- | --- |
| Three-camera enumeration | Android applications can open the main rear, secondary rear and front sensors instead of seeing no camera provider. |
| Camera location and rotation map | Camera2 receives the correct front/back role and display orientation for each stable media path. |
| minigbm plane parsing | The HAL reads Waydroid's real buffer offsets, strides and sizes, preventing corrupt mappings and one-plane assumptions. |
| Software NV12 output | The mainline software ISP can fill Android YUV and private-preview buffers when a client needs a YUV-compatible stream, without a proprietary ISP HAL. |
| EGL NV12 channel-order fix | Uses libyuv's ARGB entry point for the GPU's B,G,R,A readback, preventing the red/blue swap that makes front-camera skin tones purple. |
| Multi-output software ISP | Debayers each Bayer input once, renders each configured output, emits every buffer completion and releases the input only after the request is complete. This supports preview plus video/JPEG/analysis streams. |
| Recording profiles and Codec2 | Supplies 480p/720p H.264/AAC profiles for all three camera IDs; the validated Venus component ranks ahead of Android's still-present software fallback. |
| Bounded software-codec policy | Adds only the five Mesa-observed syscalls needed by `media.swcodec`, preventing minijail from killing the H.264 encoder while retaining the rest of Android's sandbox. |
| Venus hardware H.264 | Uses `/dev/video12` for encode and raises the accepted rear clip from 11.37 fps on software Codec2 to 18.0 fps, matching the camera source cadence. |
| MMAP compressed-output bridge | Keeps camera input DMA-BUF zero-copy, but uses kernel-owned V4L2 capture buffers because Venus rejects Waydroid dma-heap linear output blocks with `EFAULT`; only the small encoded payload is copied into Codec2. |
| Bounded hardware-codec sandbox | Adds only the observed libchrome/Mesa scheduler and poll syscalls to the Android Codec2 policy. The service still runs as Android `media` under minijail. |
| Coalesced NV12 consumers | Produces one largest NV12 source and centre-crops/scales other YUV/encoder outputs, avoiding repeated Bayer work and excess GPU readback. |
| Linear RGB mixed preview | Keeps the fast RGB preview during preview-plus-record requests while requesting CPU-writable linear gralloc storage, avoiding tiled-buffer corruption. |
| Private-preview cap | Stops CameraX selecting an oversized 1600x1200 private preview beside 720p video; full-size YUV and JPEG photography modes remain advertised. |
| Mesa EGL/libyuv software ISP | Converts the validated Android preview path through the phone's Mesa GPU stack instead of the much slower CPU-only conversion. `mode: gpu` is recorded in the runtime configuration. |
| RGB private-preview candidate | Texture-only `IMPLEMENTATION_DEFINED` streams can use Android RGBX/XBGR buffers, so the GPU output avoids the NV12 `glReadPixels()` and libyuv conversion; encoder and explicit YUV streams retain NV12. Phone acceptance is pending. |
| Native RGB release-fence candidate | When Android's EGL native-fence extension is available, GPU-written RGB preview buffers carry a native release fence and mapped RGB consumers wait on it before CPU access; the older synchronous `glFinish()` path remains the safe fallback. Phone acceptance is pending. |
| DMA-heap internal buffers | Falls back to CMA/system DMA heaps when the mainline image does not provide the legacy Android gralloc allocator. |
| YUV, JPEG and private streams | Preview, analysis and still-capture paths used by ordinary Camera2 applications all return data. |
| Logical JPEG BLOB sizing | Places the Camera3 JPEG footer at the logical buffer end expected by Android even when minigbm aligns the physical plane. |
| Valid low-frame-rate metadata | A camera whose usable mode is below 30 fps remains in Android's stream map instead of causing malformed Camera2 characteristics. |
| Variable 15–30 fps preview | In low light, applications may allow a frame to grow to about 66.7 ms for more exposure; a fixed 30 fps video request stays fixed. |
| Reduced large preview source | For aspect-preserving 1600-wide private/YUV previews, the software ISP can debayer a supported 1280-wide source and scale into Android's requested buffer; JPEG capture remains full-size. |
| Conditional preview mipmaps | The EGL scaler generates mipmaps only when it is actually downscaling; equal-size and upscaled previews avoid a full mipmap chain on every frame. |
| Redundant full-frame clear removal | The Android GPU ISP avoids two clear operations whose full-screen Bayer and scaler draws overwrite every pixel; phone acceptance is pending. |
| NV12 fence elision | After the GPU RGBA intermediate has been synchronously read back and converted by the CPU, the Android path skips a second full GPU wait; direct RGB output retains its fence. Phone acceptance is pending. |
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

- `patches/libcamera/v0.7.2/` contains the seventeen generic native patches. The
  final two add `FrameDurationLimits` and stable progressive autofocus
  transitions to simple-pipeline sensors.
- `patches/libcamera/waydroid/v0.7.2/` contains the Android-only Camera3 HAL
  series. Apply `0001` first, followed by the libyuv conversion, Mesa GPU
  software-ISP, robust DMA/JPEG, SIGPIPE-safe IPC, reduced-preview-source,
  conditional-mipmap, redundant-clear, NV12-fence, RGB-private-preview and
  EGL NV12 channel-order patches (`0002`–`0012`), multi-output software ISP
  patch `0013`, and the mixed RGB/NV12 plus private-preview patches `0014` and
  `0015`.
- `config/waydroid/camera_hal.yaml` maps stable OnePlus media paths to Android
  facing and rotation values.
- `config/waydroid/configuration.yaml` selects GPU software-ISP mode, preserves
  the input buffer and limits the soft-ISP worker count.
- `config/waydroid/init.zz-oneplus6t-camera.rc.in` is the provider override.
  Its `@VIDEO_GID@` placeholder must become the numeric postmarketOS `video`
  GID; the `zz` prefix makes the ordering explicit. It also selects the
  reviewed recording-profile file and Codec2 path during Android early init.
- `config/waydroid/media_profiles.xml` declares conservative 480p/720p
  H.264/AAC profiles for all three libcamera IDs.
- `config/waydroid/mediaswcodec.policy` is the device-specific additive
  seccomp fragment required by Mesa's software encoder path.
- `scripts/build-waydroid-camera` creates a clean Android ARMv7 libcamera build
  and runtime staging tree.
- `scripts/package-waydroid-camera` creates a tarball and matching file
  manifest from a staging tree.
- `scripts/install-waydroid-camera` performs a target-scoped backup, install
  and rollback without touching partitions or firmware. Before any backup it
  refuses to access the overlay if a `/var/lib/waydroid/rootfs` mount remains;
  this prevents a stale lowerdir mount from turning a copy into an
  uninterruptible I/O wait.
- `patches/android-v4l2-codec2/` carries the Qualcomm Venus queue-memory fix
  against the exact Android 13 V4L2 Codec2 revision.
- `scripts/prepare-waydroid-v4l2-codec-sources`,
  `build-waydroid-v4l2-codec`, `package-waydroid-v4l2-codec` and
  `install-waydroid-v4l2-codec` provide a pinned, byte-reproducible build,
  archive manifest, target-scoped install and exact rollback for the hardware
  encoder service.
- `scripts/run-waydroid-camera-probe` installs the probe APK, starts one of its
  validation/performance profiles and waits for a saved `PROBE_DONE` result.
- `tests/waydroid-camera-probe/` builds the validation APK.

The Android series depends on the generic frame-duration and autofocus work. It
is intentionally separate from pmaports because Android HAL code and its ABI
dependencies do not belong in the native Alpine package.

Optional GAPPS/Play Store initialization and the read-only package verifier are
documented in [WAYDROID-GAPPS.md](WAYDROID-GAPPS.md). The verifier is separate
from the camera overlay and does not download, initialize or modify Waydroid.

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
contains the two postmarketOS base patches and this project's seventeen generic
patches. Apply that sequence to a clean libcamera 0.7.2 source tree, then apply
the fifteen Android patches in numeric order:

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
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0007-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0008-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0009-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0010-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0011-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0012-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0013-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0014-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0015-*.patch
```

Stop if any patch rejects. Do not use `--3way` to hide a source-version
mismatch. The reviewed order ends with generic frame duration, generic
autofocus-transition stability, the Android Camera3 HAL, GPU NV12 conversion,
robust buffer/JPEG handling, SIGPIPE-safe IPA socket teardown, the
aspect-preserving reduced preview source, the RGB private-preview route and
native RGB release-fence export, followed by the EGL NV12 channel-order fix.
The seventh patch avoids mipmap
generation for equal-size and upscaled previews while retaining it for true
downscales. The eighth patch removes two redundant full-frame clears from the
Android EGL path while leaving the shaders, buffers and fallback paths
unchanged. The ninth patch removes only the post-readback `glFinish()` for
NV12 output; direct RGB DMA-BUF output retains synchronization. The fifth patch
is deliberately small: it changes only the two
libcamera IPC send calls that can otherwise deliver SIGPIPE after an IPA peer
closes. The sixth through eleventh patches are performance candidates; all six
must be accepted on the phone before they are treated as a runtime baseline.
The ninth patch is limited to NV12 output, where `glReadPixels()` already
provides the required GPU completion before the CPU writes the emitted buffer.
The tenth patch selects RGBX/XBGR only for texture-like private streams. It
keeps explicit YUV and encoder usage on NV12, imports the actual DMA-BUF
fourcc for RGB output and retains the GPU fence for buffers still written by
the GPU. The eleventh patch exports that RGB completion as an Android native
release fence when the EGL extension is available, and makes mapped RGB
consumers wait on the source fence before CPU access. If the extension is not
available, the existing synchronous `glFinish()` fallback remains in use; this
patch is a phone-gated performance candidate, not a guarantee of higher FPS.
The twelfth patch fixes the separate NV12 path: the ABGR8888 scale shader
swaps blue before `glReadPixels(GL_RGBA)`, so the returned B,G,R,A bytes must
be passed to libyuv's little-endian `ARGBToNV12()` entry point. This is the
channel-order correction for the purple front-camera preview; RGB private
preview streams are unchanged. Patch `0013` maps configured streams to output
indexes, reuses one GPU Bayer pass for all outputs, renders/scales each target,
runs statistics once and emits every completion. Patch `0014` then keeps the
private preview on RGB during a mixed request by asking minigbm for
CPU-writable linear storage; it coalesces the remaining NV12 streams through
one largest source and centre-crops/scales mapped consumers. Patch `0015` caps
only implementation-defined private streams at 1280x960. This avoids CameraX's
1600x1200 preview forcing a slower raw mode beside 720p recording while
retaining larger explicit YUV and JPEG photography modes.

## Build a runtime bundle

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
  /path/to/waydroid-camera-nv12-r36-fix
```

The helper configures only the simple pipeline/IPA and generic Android HAL,
builds for ARMv7, signs the IPA with the build-local key, installs under the
staging `vendor/` tree, adds `libc++_shared.so`, and installs the reviewed
OnePlus tuning, camera map, recording profiles, software-codec policy and GPU
configuration. `enabled` selects the
validated Mesa path; `auto` lets Meson choose and `disabled` is a CPU-only
fallback for diagnosis. The generated IPA private key remains in the build
directory and must not be committed. Build and stage directories must be new
or empty; this prevents mixing signed IPAs or libraries from different builds.

At minimum, retain these runtime files together:

```text
vendor/etc/libcamera/camera_hal.yaml
vendor/etc/libcamera/configuration.yaml
vendor/etc/media_profiles.xml
vendor/etc/media_profiles_V1_0.xml
vendor_extra/etc/seccomp_policy/mediaswcodec.policy
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
pmos-check-waydroid-health --status --processes \
  --output /private/path/oneplus6t-waydroid-health.txt
```

Proceed only when the report contains:

```text
rootfs_mounts=0
overlay_precondition=pass
```

The check also records `/proc/loadavg` and `/proc/pressure/io`, including both
the `some` and `full` `avg10` values. Either non-zero value blocks the
operation: `full` pressure is especially important because it means all
non-idle tasks are waiting on I/O even if the `some` line looks clear. The
check does not stop Waydroid, unmount anything, kill a process or write the
overlay. If a rootfs mount remains or storage I/O is pressured, recover the
phone and repeat the report before using the installer. With `--processes`, it
also reports D-state installer, Waydroid-container-start and reboot helper
commands for recovery auditing; it does not claim that a signal or stop
command succeeded. The installer independently rechecks
`/proc/self/mountinfo` and both PSI lines and refuses a mounted rootfs, active
I/O pressure or unavailable pressure data.

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

The installer reads `/proc/self/mountinfo` and `/proc/pressure/io` before both
installation and rollback. If Waydroid's rootfs or one of its child mounts is
still present, either PSI `avg10` value is non-zero, or pressure data is
incomplete, it fails immediately. `WAYDROID_ROOTFS_DIR`,
`WAYDROID_CAMERA_MOUNTINFO` and `WAYDROID_CAMERA_PROC_ROOT` are available for a
nonstandard layout or test fixture. Do not bypass this check while the rootfs
is mounted or storage is pressured: the overlay is a lower directory of that
rootfs, and copying its files can deadlock the storage path.

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

The default `full` profile keeps the complete acceptance coverage. To separate
preview throughput from the cost of additional Camera2 streams, run the same
APK with `--es profile preview` for private preview only or
`--es profile preview-yuv` for private plus YUV, as documented in the probe
README. The additional `surface` profile renders the private stream to a real
Android `TextureView` and reports `privateTimingSource=surface`, so it measures
updates reaching the displayed viewfinder rather than only buffers delivered
to an `ImageReader`. It also records one asynchronous `PixelCopy` RGB sample
(`surfaceRgbMean`/`surfaceRgbRange`) to expose channel swaps or an all-black
surface without adding readback to the repeating capture path. A private-only
result below the camera application's visible frame rate points to
provider/software-ISP or Waydroid compositor work; compare it with `surface`
to locate the boundary. The `record` profile uses Camera2's
`TEMPLATE_RECORD` with the same displayed `TextureView`, so a rate drop only in
that profile points to the recording template or its negotiated stream. It
prefers an advertised fixed 30 FPS range and reports the chosen fallback when
30 FPS is unavailable; it never invents a range. Surface update callbacks are
coalesced before timing samples are dispatched to the camera worker, so a UI
callback backlog does not inflate the measured rate. The profile is diagnostic
and does not invoke an encoder or save a file. A large drop only when YUV/JPEG
is added points to multi-stream conversion load. This distinction is required
before changing
the GPU default: the r35 NV12 baseline still reads an
RGBA frame back to CPU memory and converts it to Android NV12. Patch 0010 adds
a separate texture-only private RGB route that avoids that readback;
explicit YUV and encoder streams keep the old path. Patch 0011 can replace the
RGB path's blocking completion with an Android native release fence when the
EGL extension is present; it leaves the synchronous fallback intact. Patch
0012 corrects the red/blue order in the NV12 conversion used by the r36
single-output preview. Patch 0013 supports multiple outputs but deliberately
routes mixed private/encoder requests through layout-stable NV12. This is why
`preview`, `preview-yuv`, `surface` and `record` must still be compared: an RGB
single preview can be faster while a correct multi-stream video request
remains NV12-bound.

For the front-camera colour regression, run the `surface` profile while
pointing the camera at a face or a red/blue reference object. On the affected
r35 path, the preview remains valid but red and blue are exchanged. After the
r36 bundle is installed, the same scene must show natural skin tones and the
rear-camera colours must remain unchanged. The probe's RGB sample is useful for
detecting a channel swap, but visual colour-chart or skin-tone review is still
required; this patch does not add Android-vendor colour calibration.

The installed `pmos-compare-waydroid-camera-probes` helper compares two saved
results from the same profile. It verifies matching camera IDs and valid
records, reports per-camera FPS deltas and preserves the surface RGB evidence
for review. It is intentionally a reporting tool, not an automatic approval:
visual colour/order, JPEG, exposure/focus and provider lifecycle checks still
decide whether a candidate is retained.

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

## Waydroid r36 front-camera colour fix

Date: 2026-08-27. The installed r35 Waydroid path was delivering valid private
preview frames, but its GPU NV12 conversion passed B,G,R,A `glReadPixels()`
bytes to libyuv's ABGR entry point. That exchanged red and blue, producing the
purple skin tones seen in the front-camera viewfinder. The Android provider log
also confirmed that this path uses the Mesa EGL renderer (`FD630`) and the
software ISP, so the defect is below the camera application.

Patch `0012` changes only that conversion to `ARGBToNV12()`, whose little-endian
input order matches B,G,R,A. The RGB private-preview route is not changed. The
conversion naming follows libyuv's documented ARGB/ABGR byte-order distinction
in its [conversion header](https://chromium.googlesource.com/libyuv/libyuv/+/refs/heads/main/include/libyuv/convert_from_argb.h).

The bundle was built from the exact r35 source tree with ARMv7/API 33,
`softisp-gpu=enabled`, and a build-local IPA signature. The host package
manifest matched on the phone. The guarded installer passed with zero rootfs
mounts and zero PSI I/O pressure, created the rollback backup below, and
installed all 13 managed runtime files:

```text
libcamera source base: deaa218
0012-android-fix-EGL-NV12-channel-order.patch:  0acd6ac1895dbef0a46c3ba95fec789ff34d0b342471f9f8025580204433ff98
waydroid-camera-nv12-r36-fix.tar.gz:  f4e2adfa81eb87398d262ff9b5249b3b05a0bd4bbcdd9b73ed1fc10213a3fb13
waydroid-camera-nv12-r36-fix.sha256:  b97d178c7c97b71e508e8915696fc20e8f2ecc3c882bbcb1e7e8dd845df34d7a
probe APK: ba99b76e1c107beff05da165ddbae368399fd3aef2580ebf12345ebed372b51e
backup: /var/lib/waydroid/backups/camera-20260827T143502Z-74465
```

Post-install evidence:

- the `surface` profile completed `valid=3 total=3`, with the front camera
  reported as `id=0`, and saved a 1600x1200 displayed frame;
- the front frame's orange and teal reference objects render with normal
  red/blue relationships rather than the previous purple cast; and
- the private `preview` profile completed `valid=3 total=3` for all cameras.

At the r36 checkpoint the full diagnostic still reported `capture session
configuration failed` for simultaneous private preview plus YUV, with
`DebayerEGL: Unsupported number of output streams: 2`. That evidence correctly
separated the colour fix from the one-output limitation. Patch `0013` and the
r41/r42 work below address that lower-layer limit.

## Waydroid r41/r42 multi-output video acceptance

Date: 2026-08-27. CameraX could already read 720p H.264/AAC profiles, but
Aperture configured a 1600x1200 preview together with a 1280x720 encoder
surface. `SoftwareIsp`, `DebayerEGL` and the CPU fallback accepted exactly one
output, so Camera3 rejected that otherwise valid request.

Patch `0013` carries all request outputs through the software ISP, renders the
Bayer input once on the GPU, scales each output independently, computes
statistics once and releases every output/input buffer exactly once. The CPU
fallback remains explicitly single-output until it has an equivalent tested
implementation. In mixed requests, private buffers use NV12 to avoid importing
Waydroid/minigbm tiled allocations as falsely linear RGB.

The overlay also installs both Android recording-profile filenames, selects
Codec2 during early init and adds a five-syscall device policy for Mesa's
`media.swcodec` process. The profile declares conservative 480p/720p H.264/AAC
modes at each camera's live Camera2 maximum (front 24 fps, rear main 19 fps and
rear auxiliary 15 fps); it does not claim 1080p/4K support that has not been
accepted on this stack.

The installed r41 bundle passed the health gate, retained backup
`/var/lib/waydroid/backups/camera-20260827T212305Z-63014`, and produced this
live result in Aperture:

- CameraX configured simultaneous preview and encoder outputs;
- Codec2 emitted a video keyframe and started the MP4 muxer;
- both first-video and first-audio timestamps arrived, then encoding ended
  successfully;
- the saved 2,223,809-byte file probes as H.264 1280x720 for 19.056 seconds
  plus mono AAC at 48 kHz for 19.029 seconds (19.148-second container); and
- playing that clip created a PipeWire sink input on the physical speaker.

The microphone bridge was independently active as a 16 kHz two-channel
Waydroid capture stream while recording. The clip remains private and is not
stored in this repository.

After acceptance, the source was formatted and committed as a standalone
libcamera patch. It passes the project's style checker, reapplies cleanly after
`0012`, and a fresh Android ARMv7/API-33 build completed all 198 targets. The
r42 camera HAL is byte-identical to the installed r41 HAL; build metadata and
the deliberately build-local IPA key make other package hashes differ.

```text
0013 patch: 729943ef624a283cdccf62a292e74938cd320c940d5260b2ec97c4aa02543420
r41 archive: 03ab130dd027e7786401ab261a8f50460d0acd71bb1bee206f8a3012d90cb703
r41 manifest: 6439d413af4deecb7b31346e36089a9ff1e93ff4caf25149db2ea507b8ed53a4
r42 archive: af1d6c7f41b2c72cae362f008bdb7ccb22f238ebf786a850f6afd8ec1a6a4cf4
r42 manifest: cf87fde5a123b3231a53c78e8eaba1dfe9552980399df6c844d324d1cc058c65
camera.libcamera.so: f96b36afc32fc09f80cb70c9377d41aa8b982e7699fb7fa4dcdced747164aea0
```

This accepts one real rear-camera Aperture recording. Front and auxiliary
recording, long clips, app switching and suspend/resume still need separate
physical tests. The open path also remains slower and less processed than the
OnePlus Android vendor camera.

## r44 camera streams and r50/r51 Venus hardware encoding

Date: 2026-08-28. The next camera layer keeps an RGB private preview during a
mixed CameraX request and maps all NV12 consumers to one largest source. A
separate cap removes private preview sizes above 1280x960 while retaining
larger explicit YUV and JPEG modes. These changes are patches `0014` and
`0015`; their SHA-256 values are:

```text
0014: 00adcb38c1223b634bf5304c045da1d360bed3144f4dc4b7998d8316bd8d5d5d
0015: f9bd5452c9b33fbefef5b21479e4e354a241471c5b63431fa769826ca06a67b7
```

The r44 camera overlay is installed. Its source tree was reconstructed by
applying `0014` and `0015` directly after `0013` and matched the installed
candidate tree exactly. The intervening direct-NV12-GPU experiment was
reverted and is not part of either patch.

Android's software H.264 encoder remained the next bottleneck. A control clip
contained 516 frames over 45.370 seconds, or 11.37 fps. The SDM845 kernel
exposes the Qualcomm Venus stateful encoder at `/dev/video12`, but upstream
Android 13 V4L2 Codec2 could not be installed unchanged:

- every `V4L2Buffer` was accidentally forced to `V4L2_MEMORY_DMABUF`, even
  when its queue requested MMAP;
- Venus accepts the camera's single-buffer NV12 DMA-BUF input but needs the
  complete Y+UV allocation described through its one V4L2 plane;
- Venus rejected Waydroid's dma-heap Codec2 block on the compressed capture
  queue with `VIDIOC_QBUF` returning `EFAULT`; and
- the destination Codec2 block needed CPU-write usage before the service could
  copy a kernel-owned compressed payload into it.

The patch keeps camera input DMA-BUF zero-copy, uses MMAP only for the small
compressed V4L2 capture buffers, validates their offset/length and copies each
encoded payload into Codec2. It is pinned to Android source commit
`6cf3be6acb0e321459172ec12824f448e1c14b9e`; the patch hash is:

```text
0a70f1c34f44918eea3080cd081906f3a0584c099d440502f93823398390658b
```

The service is registered from `/system`, not `/vendor`, so Android's linker
namespace can resolve the Android 13 system Codec2 ABI. Only
`c2.v4l2.avc.encoder` is published. Rank `0` places it before Lineage's
property-forced rank-`1` `c2.android.avc.encoder`; the software component stays
available as fallback. Minijail remains enabled. Its extension adds the two
calls observed during hardware startup, `sched_getaffinity` and
`sched_setscheduler`, plus the libchrome poll/event calls already required by
the service.

The live r50 result selected `c2.v4l2.avc.encoder`, kept the service alive and
finalized without CameraX or Codec2 errors. The private rear clip probes as:

```text
video: H.264 1280x720, 460 frames, 25.556311 s, exactly 18.0 fps
audio: AAC mono, 48000 Hz, 25.499312 s
container: 25.556600 s, 12397839 bytes
```

That cadence matches the approximately 18.96 fps delivered by the rear camera
source and is materially above the 11.37 fps software control. The lens faced
a dark surface during both automated recordings, so their matching dark scene
is useful as an encoder-path control but is not colour-chart acceptance. Front
video, an illuminated rear scene and auxiliary-camera recording remain
required.

### Reproduce the hardware encoder

The preparation helper fetches seven exact Android source revisions from
`android.googlesource.com` and applies the patch. The build requires Android
NDK `25.2.9519653`, API 33, `hidl-gen`, and the arm64 shared libraries from the
same Android 13 Waydroid system image. Do not link native Linux libraries or
libraries from a different Android image.

```sh
mkdir /tmp/codec-sources
scripts/prepare-waydroid-v4l2-codec-sources /tmp/codec-sources

export ANDROID_NDK_ROOT=/absolute/path/to/android-ndk-25.2.9519653
export WAYDROID_LINK_LIB64=/absolute/path/to/android13/system/lib64:/absolute/path/to/extra-apex-libs
scripts/build-waydroid-v4l2-codec \
  /tmp/codec-sources /tmp/codec-build /tmp/codec-stage
scripts/package-waydroid-v4l2-codec \
  /tmp/codec-stage /tmp/oneplus6t-waydroid-v4l2-codec-r51
```

Both output directories must be absent or empty. Two complete builds from
different source and output paths produced byte-identical staged files. The
packager normalizes order, ownership and timestamps; two package runs are also
byte-identical. The reproducible r51 hashes are:

```text
archive: 28997d11899b3b12140e5377febdd47d71ab99d21de703a122f76d59ba3c2b16
manifest: 7334f62d48de679de01bb344f3dd7d630803ea4067e987d22fc44b7b795fd8ff
service: df13a5a1792ea657405dbac0d5d95d3345ee12ca229cd4f69699809300e9a8d8
plugin: eb61890494acee634529634a154faed923b2b77813ab7b2da0ff8c09f9db63f6
common: 1b4a5aabb7fa3a3fb66ca13e458a9ca0cb3ab28728e6fe990979949226c86cba
components: 77f60101877df931c423974e108fda9f478af05b47d9dd5735162098024ad670
```

The exact r51 binaries are source/package accepted but still need installation
on the phone; the live r50 binaries were built from the same patched source but
before path-normalized clean rebuilding. The archive and per-file manifest are
published as the
[r51 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-v4l2-codec-r51).
To install, first stop both the Waydroid session and container and require an
unmounted rootfs with zero PSI I/O pressure. Extract the archive into an empty
staging directory, then run:

```sh
sudo scripts/install-waydroid-v4l2-codec /absolute/path/to/codec-stage
```

The installer manages nine exact files, creates a dated backup and refuses a
mounted rootfs, active I/O pressure, missing stage file, broad path, symlink or
directory target. Its rollback form is:

```sh
sudo scripts/install-waydroid-v4l2-codec --rollback \
  /var/lib/waydroid/backups/codec-YYYYMMDDTHHMMSSZ-PID
```

After the r50 recording had finalized, interrupting a foreground Waydroid
session left Android init as a zombie and one Android process in uninterruptible
kernel I/O. The existing overlay health gate correctly makes any further
overlay operation unsafe in that state, and even normal systemd reboot/sync can
wait behind it. Do not force an install through that gate; perform a physical
power-button reboot, confirm the rootfs is unmounted, then test the exact r51
archive. The recording itself completed before the teardown and the hardware
Codec2 service did not log a crash.

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
- The Android preview path currently has a synchronous RGBA readback followed
  by NV12 conversion when the implementation-defined buffer is NV12. This is
  a known performance boundary of the open-source path; use the probe's
  isolated profiles to measure it before selecting a different build mode.
- Running the probe while Aperture or another camera client owns CAMSS can
  produce a transient media-link-busy result; stop camera clients and rerun the
  probe before treating it as a regression.
- Camera2 numeric IDs are provider enumeration details; applications should
  use facing/characteristics rather than assuming a fixed number.
- Play Store installation, GPS and the Waydroid location bridge are separate
  roadmap items. They are not claimed by this camera patch.
