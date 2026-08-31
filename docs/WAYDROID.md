# Waydroid camera support

This document covers the open-source Camera3 path used by Android 13 in
Waydroid on the OnePlus 6T. It uses the mainline kernel cameras and libcamera's
software ISP. It does not copy OnePlus/OxygenOS camera libraries, calibration
blobs or firmware.

The reference phone runs Waydroid 1.6.3 with the pinned Android 13 ARM64
Vanilla/MAINLINE image pair in [WAYDROID-VANILLA.md](WAYDROID-VANILLA.md).
The current r53 provider enumeration is stable for this phone: Camera2 ID 0 is
the main rear module, ID 1 is the fixed-focus front module and ID 2 is the
auxiliary rear module. The older r50/r51 checkpoints below were written before
the current provider ordering was accepted; their ID-specific recording notes
are historical and are not the current safety policy.
The r52 camera bundle is complete on a clean image: it carries the required
32-bit legacy provider service and implementation in addition to the accepted
r51/r50 Camera3 stack. It exposes three Android cameras and advertises
recording only for the accepted main and front cameras; auxiliary preview,
YUV and JPEG remain enabled.
Patches `0013`–`0019` add multi-output processing, retain a fast linear RGB
preview beside coalesced NV12 consumers and cap private previews to a sensor
mode suitable for video. Patch `0016` writes a compatible contiguous NV12
allocation directly on the GPU while retaining the readback/libyuv fallback;
`0017` waits for that GPU source before mapped YUV/JPEG post-processing.
`0018` drains those asynchronous post-processors before the Camera3 HAL drops
request descriptors and streams, and restarts them after Android `flush()` so
the next configure/open cannot inherit a late completion.
Patch `0019` forwards Android `LENS_FOCUS_DISTANCE`/`AF_MODE_OFF` to the
simple-IPA manual lens contract and subtracts the sensor active-array origin
from Android AF regions. A guarded r53-static10-focus provider overlay is
installed on the reference phone and has passed repeated preview reopen tests,
manual focus on both rear IDs, tap-focus region/state checks and full YUV/JPEG/
private-preview probes on all three camera IDs. Ordinary third-party
camera-app acceptance remains a separate gate.
A separate Android 13 arm64 Codec2 service uses the SDM845 Venus encoder while
preserving Android's software encoder as fallback. Aperture now configures
simultaneous preview and encoder streams and saves playable H.264/AAC video.
The native postmarketOS stack remains separate in [CAMERA.md](CAMERA.md).

## Latest runtime checkpoint

On 2026-08-31 the full protected Camera2 probe returned valid YUV and JPEG
frames for IDs 0, 1 and 2, with zero JPEG row discontinuities. Rear IDs 0 and
2 returned AF states `[3, 4]` and centre regions; fixed-focus front ID 1
returned state `[0]` with no AF region. The recording-profile audit found the
image-level files still advertised the old safe-ID arrangement; the checked-in
profile correction now targets main rear ID 0 and front ID 1.
Auxiliary rear ID 2 remains preview/YUV/JPEG-only because its two reproducible
Venus teardown faults make ordinary encoding unsafe.

The runner must be used while a single graphical Waydroid session is held
open. The reference image freezes an idle container for battery life, and a
root-side SSH probe cannot reliably keep that session alive by itself. Before
doing any package or activity operation, the runner now performs bounded
`waydroid status` and shell calls and rejects a stopped or still-frozen
container; this makes a bad lifecycle state fail promptly instead of leaving
an SSH session blocked on a torn-down LXC container. Its temporary sleep
inhibitor and explicit thaw are bounded to the probe; the normal freeze-on-idle
policy is restored afterward. Saved `PixelCopy` surface samples are diagnostic
only until an interactive Android camera app is accepted on the visible
compositor.

## Features and their benefit

| Feature | What it brings |
| --- | --- |
| Clean-image provider bundle | Includes the reviewed 32-bit legacy provider service, implementation libraries and VINTF declaration, so a fresh ARM64 Vanilla image does not depend on leftovers from an older Waydroid generation. |
| Three-camera enumeration | Android applications can open the main rear, secondary rear and front sensors instead of seeing no camera provider. |
| Camera location and rotation map | Camera2 receives the correct front/back role and display orientation for each stable media path: rear IDs 0/2 and front ID 1. |
| minigbm plane parsing | The HAL reads Waydroid's real buffer offsets, strides and sizes, preventing corrupt mappings and one-plane assumptions. |
| Software NV12 output | The mainline software ISP can fill Android YUV and private-preview buffers when a client needs a YUV-compatible stream, without a proprietary ISP HAL. |
| EGL NV12 channel-order fix | Uses libyuv's ARGB entry point for the GPU's B,G,R,A readback, preventing the red/blue swap that makes front-camera skin tones purple. |
| Multi-output software ISP | Debayers each Bayer input once, renders each configured output, emits every buffer completion and releases the input only after the request is complete. This supports preview plus video/JPEG/analysis streams. |
| Recording profiles and Codec2 | Supplies 480p/720p H.264/AAC profiles for main rear ID 0 and front ID 1; the validated Venus component ranks ahead of Android's still-present software fallback. Auxiliary rear ID 2 has only a non-recording high-speed sentinel because Android's parser requires contiguous IDs; ordinary auxiliary video remains blocked after a reproducible Venus teardown fault. |
| Recording-profile synchronizer | Copies the checked-in, safe camera-ID mapping into both Android recording-profile filenames after a stopped-rootfs preflight. It backs up the exact previous files and supports a bounded rollback, fixing image-level files that advertise the stale ID arrangement while retaining the parser-safe ID 2 sentinel. |
| Bounded software-codec policy | Adds only the five Mesa-observed syscalls needed by `media.swcodec`, preventing minijail from killing the H.264 encoder while retaining the rest of Android's sandbox. |
| Venus hardware H.264 | Uses `/dev/video12` for encode. Codec2 r53 completes repeated rear H.264/AAC recordings and teardown; the current illuminated file still averages only 11.62 fps, so this is functional acceptance rather than performance parity. |
| MMAP compressed-output bridge | Keeps camera input DMA-BUF zero-copy, but uses kernel-owned V4L2 capture buffers because Venus rejects Waydroid dma-heap linear output blocks with `EFAULT`; only the small encoded payload is copied into Codec2. |
| Venus input-layout and lifetime fix | Describes the full single-plane NV12 allocation to Venus, keeps imported camera buffers alive through dequeue and destroys the encoder before its format converter. This removes the former green lower band and unsafe teardown ordering. |
| Metadata-only stride discovery | Reads the temporary Codec2 allocation's gralloc stride from its native handle without mapping/importing it, avoiding the minigbm/Mesa `gbm_bo_unmap` crash seen during encoder initialization. |
| Bounded hardware-codec sandbox | Adds only the observed libchrome/Mesa scheduler and poll syscalls to the Android Codec2 policy. The service still runs as Android `media` under minijail. |
| Coalesced NV12 consumers | Produces one largest NV12 source and centre-crops/scales other YUV/encoder outputs, avoiding repeated Bayer work and excess GPU readback. |
| Contiguous NV12 GPU target | Imports compatible linear Y+UV planes as one `GR88` framebuffer and writes filtered luma/chroma in a single draw, avoiding `glReadPixels()` and CPU colour conversion while preserving the safe fallback for other layouts. |
| Post-processor source-fence wait | Waits once per GPU-written source before mapped YUV/JPEG consumers run, preventing partially rendered scan lines while direct-only Android outputs retain asynchronous completion fences. |
| Camera worker lifecycle drain | Waits for asynchronous YUV/JPEG workers before releasing Camera3 descriptors and streams, then restarts them after Android `flush()` so close/reconfigure and stream reuse do not race late completions. |
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
| Rear manual focus | Camera2 `LENS_FOCUS_DISTANCE` maps to the simple-IPA `LensPosition` 0.0–2.0 contract and moves both rear actuators; result metadata is echoed back. |
| Correct AF-region origin | Android active-array coordinates are converted to the libcamera active-area-relative `AfWindows` coordinates before the simple IPA evaluates them. |
| Fixed-focus reporting | The front camera honestly advertises no autofocus instead of accepting controls that cannot move hardware. |
| SIGPIPE-safe IPA teardown | A closed software-IPA Unix socket returns `EPIPE` through libcamera's existing error path instead of killing the Android provider with signal 13. |
| Automated Camera2 probe | A reproducible APK verifies every stream, AF state and exposure path without depending on a store camera application. |

These are lower-layer camera features. They do not add a polished Android
camera UI by themselves; an Android camera application consumes them.

## Source layout

- `patches/libcamera/v0.7.2/` contains the eighteen generic native patches. The
  final three add `FrameDurationLimits`, stable progressive autofocus
  transitions and the bounded `LensPosition` manual-focus contract to
  simple-pipeline sensors.
- `patches/libcamera/waydroid/v0.7.2/` contains the Android-only Camera3 HAL
  series. Apply `0001` first, followed by the libyuv conversion, Mesa GPU
  software-ISP, robust DMA/JPEG, SIGPIPE-safe IPC, reduced-preview-source,
  conditional-mipmap, redundant-clear, NV12-fence, RGB-private-preview and
  EGL NV12 channel-order patches (`0002`–`0012`), multi-output software ISP
  patch `0013`, and the mixed RGB/NV12 plus private-preview patches `0014` and
  `0015`. Patch `0016` adds the accepted contiguous-NV12 GPU target and keeps
  the existing readback/libyuv conversion as its runtime fallback. Patch
  `0017` synchronizes only CPU-mapped post-processors with their GPU source.
  Patch `0018` drains all post-processors before stream/descriptors reset and
  makes Android `flush()` workers restartable. Patch `0019` adds manual focus
  and corrects AF-region coordinates for the OnePlus active arrays.
- `config/waydroid/camera_hal.yaml` maps stable OnePlus media paths to Android
  facing and rotation values.
- `config/waydroid/configuration.yaml` selects GPU software-ISP mode, preserves
  the input buffer and limits the soft-ISP worker count.
- `config/waydroid/init.zz-oneplus6t-camera.rc.in` is the provider override.
  Its `@VIDEO_GID@` placeholder must become the numeric postmarketOS `video`
  GID; the `zz` prefix makes the ordering explicit. It also selects the
  reviewed recording-profile file and Codec2 path during Android early init.
- `config/waydroid/legacy-libcamera.xml` declares the provider's `legacy/0`
  HIDL instance to Android's framework compatibility matrix.
- `config/waydroid/media_profiles.xml` declares conservative 480p/720p
  H.264/AAC profiles for main rear ID 0 and front ID 1. It contains only a
  high-speed CIF sentinel for auxiliary rear ID 2 because Android's
  `MediaProfiles` required-profile table assumes contiguous IDs; no ordinary
  auxiliary profile is advertised until a non-Venus path or kernel/Codec2 fix
  is accepted.
- `config/waydroid/mediaswcodec.policy` is the device-specific additive
  seccomp fragment required by Mesa's software encoder path.
- `scripts/prepare-waydroid-camera-provider` extracts and verifies the four
  required ELF32 ARM provider files from a separately hash-verified official
  Waydroid ARM vendor image without mounting or modifying it.
- `scripts/build-waydroid-camera` creates a clean Android ARMv7 libcamera build
  and complete runtime staging tree, including that provider prefix.
- `scripts/package-waydroid-camera` creates a tarball and matching file
  manifest from a staging tree.
- `scripts/install-waydroid-camera` performs a target-scoped backup, install
  and rollback without touching partitions or firmware. Before any backup it
  refuses to access the overlay if a `/var/lib/waydroid/rootfs` mount remains;
  this prevents a stale lowerdir mount from turning a copy into an
  uninterruptible I/O wait.
- `scripts/sync-waydroid-camera-profiles` repairs only
  `vendor/etc/media_profiles.xml` and `vendor/etc/media_profiles_V1_0.xml`
  in the host overlay. It validates that the checked-in source advertises
  only ordinary recording-capable IDs 0 and 1 plus the parser-only ID 2
  sentinel, refuses symlink/directory targets,
  requires an unmounted rootfs and zero storage-I/O PSI pressure, records a
  dated exact backup, and supports rollback. This is needed when an otherwise
  correct provider is paired with a stale image-level profile file: the live
  provider order is 0 rear main, 1 front, 2 auxiliary rear, while the old
  profile file can incorrectly advertise the auxiliary ID and omit front video.
  The sentinel is
  deliberately high-speed-only and is not a supported ordinary video path.
- `patches/android-v4l2-codec2/` carries the Qualcomm Venus queue-memory,
  single-plane layout/lifetime and metadata-only temporary-stride series
  against the exact Android 13 V4L2 Codec2 revision.
- `scripts/prepare-waydroid-v4l2-codec-sources`,
  `build-waydroid-v4l2-codec`, `package-waydroid-v4l2-codec` and
  `install-waydroid-v4l2-codec` provide a pinned, byte-reproducible build,
  archive manifest, target-scoped install and exact rollback for the hardware
  encoder service.
- `scripts/run-waydroid-camera-probe` installs the probe APK, starts one of its
  validation/performance profiles and waits for a saved `PROBE_DONE` result;
  repeated A/B runs can verify and reuse the installed package instead of
  updating it between samples. Because the supported idle power policy freezes
  the container, the runner tries to hold a temporary `systemd-inhibit` lock
  for the duration of each invocation and thaws it before an SSH-launched
  probe by default. If an SSH session can enumerate inhibitors but is not
  authorized to create one, the runner reports that and continues without the
  lock; the normal battery policy is unchanged after the command exits.
  On the reference image `waydroid shell` is root-only, so invoke the runner
  as `sudo pmos-run-waydroid-camera-probe ...`; the helper reports this
  requirement directly when called unprivileged.
  Set `PMOS_WAYDROID_PROBE_UNFREEZE=no` when the session is already known to be
  active. `PMOS_WAYDROID_PROBE_CONTROL_TIMEOUT` bounds these control commands.
- `tests/waydroid-camera-probe/` builds the validation APK.

The Android series depends on the generic frame-duration and autofocus work. It
is intentionally separate from pmaports because Android HAL code and its ABI
dependencies do not belong in the native Alpine package.

The Camera2 diagnostic closes a device asynchronously. It stops repeating
requests, aborts pending captures, waits for `CameraDevice.StateCallback`'s
`onClosed()` callback, and only then releases the old surfaces or opens the
next sensor. This ordering is required for repeated camera switching on the
OnePlus provider; opening the next sensor while the previous close is still
draining can surface as an intermittent stream timeout even when an isolated
camera open succeeds. The shared HAL's `0018` patch applies the same ownership
boundary to its worker threads: `CameraDevice::stop()` drains mapped YUV/JPEG
workers before releasing descriptors and streams, while `flush()` drains and
restarts configured workers for reuse.

The accepted Google-free image, exact hashes and read-only verifier are in
[WAYDROID-VANILLA.md](WAYDROID-VANILLA.md). Optional GAPPS/Play Store setup is
kept separately in [WAYDROID-GAPPS.md](WAYDROID-GAPPS.md); neither verifier
downloads, initializes or modifies Waydroid.

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
- the accepted Android 13 ARM64 Vanilla/MAINLINE image with its ARMv7 ABI;
- root access for the overlay installation.

Do not install these ARMv7 Android libraries into native `/usr/lib`.

## Prepare the source

Apply the pmaports integration patch first. Its resulting libcamera recipe
contains the two postmarketOS base patches and this project's eighteen generic
patches. Apply that sequence to a clean libcamera 0.7.2 source tree, then apply
the nineteen Android patches in numeric order:

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
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0016-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0017-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0018-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/0019-*.patch
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
retaining larger explicit YUV and JPEG photography modes. Patch `0016` checks
that the NV12 planes share one backing DMA-BUF and are contiguous, imports the
whole allocation as one two-channel framebuffer, and writes two luma bytes or
one U/V pair per fragment. It preserves five-tap luma sharpness, averages the
four RGB samples in each 2x2 chroma block and exports a native completion fence.
Unsupported, non-contiguous or failed imports automatically use the existing
readback/libyuv path. Patch `0017` collects the unique GPU sources needed by
pending mapped post-processors, waits on each source fence once and only then
dispatches YUV/JPEG workers. This avoids both premature CPU reads and multiple
consumers racing ownership of the same release fence. Requests whose outputs
all go directly to Android keep the asynchronous fence path. Patch `0018`
drains the same worker queues before CameraDevice releases descriptors and
streams, and restarts them after a reusable Android `flush()`.

## Build a runtime bundle

The clean-image bundle takes its generic legacy provider from the official
Waydroid ARM vendor archive
`lineage-18.1-20250628-MAINLINE-waydroid_arm-vendor.zip`. Verify its SHA-256
`4178016188dd9871058af6fced3c66a42ad4c3fb89a8e5735e144f95ac609f9c`
before extracting `vendor.img`, then prepare an isolated prefix:

```sh
scripts/prepare-waydroid-camera-provider \
  /private/stage/waydroid-arm-vendor.img \
  /private/stage/waydroid-provider-prefix
```

The preparer requires `debugfs` and `readelf`, refuses a non-empty output,
checks every extracted file is little-endian ELF32 ARM, and prints their
SHA-256 values. The accepted provider hashes are recorded in the r52 release;
do not substitute provider files from OxygenOS or an unrelated Android build.

```sh
export ANDROID_NDK_ROOT=/path/to/Android/Sdk/ndk/29.0.14206865
export WAYDROID_DEPS_PREFIX=/path/to/android-armv7-dependencies
export WAYDROID_PROVIDER_PREFIX=/private/stage/waydroid-provider-prefix
export ANDROID_API=33
export WAYDROID_SOFTISP_GPU=enabled

/path/to/oneplus6t-pmos-fixes/scripts/build-waydroid-camera \
  /path/to/libcamera-waydroid \
  /path/to/build-waydroid-camera \
  /path/to/stage-waydroid-camera

/path/to/oneplus6t-pmos-fixes/scripts/package-waydroid-camera \
  /path/to/stage-waydroid-camera \
  /path/to/oneplus6t-camera-r52-vanilla-complete
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
vendor/bin/hw/android.hardware.camera.provider@2.4-service
vendor/lib/hw/android.hardware.camera.provider@2.4-impl.so
vendor/lib/hw/android.hardware.camera.provider@2.4-legacy.so
vendor/lib/hw/camera.device@1.0-impl.so
vendor/etc/libcamera/camera_hal.yaml
vendor/etc/libcamera/configuration.yaml
vendor/etc/media_profiles.xml
vendor/etc/media_profiles_V1_0.xml
vendor/etc/vintf/manifest/legacy-libcamera.xml
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

The installer manages the 21 runtime files plus
`system/etc/init/init.zz-oneplus6t-camera.rc` and the host
`waydroid_base.prop`/`waydroid.prop` camera property. It creates a dated backup under
`/var/lib/waydroid/backups/` and prints its path. Set
`WAYDROID_CAMERA_BACKUP_ROOT` to use another backup root. Shared objects, YAML
and the signature are mode 0644; provider executables and the software-IPA
proxy are mode 0755. The
provider override runs as Android's `cameraserver`, adds the host video GID so
it can open the mainline media devices, and writes bounded diagnostic logs to
`/data/local/tmp/libcamera-provider.log` inside Android.

Start the container as root and the session as the normal graphical user:

```sh
sudo waydroid container start
waydroid session start
```

This operation does not alter a partition, boot slot, kernel or firmware and
does not require a phone reboot. The installer does not start or stop services;
that is kept explicit so it cannot unexpectedly interrupt a camera session.

### Persistent graphical-session startup

Do not keep the Waydroid session attached to an SSH login scope. When that
scope closes, systemd can terminate the session even though the container is
still healthy. The package includes a disabled system service for the default
postmarketOS Phosh/greetd session on the OnePlus 6T. It binds the session to
`waydroid-container.service`, waits for the Wayland socket, and runs it as
`greetd` with the existing `/run/user/114` graphical bus:

```sh
sudo systemctl enable --now oneplus6t-waydroid-session.service
systemctl status oneplus6t-waydroid-session.service
waydroid status
```

Enable it only after the Vanilla image, camera overlay and health preflight
pass. The package does not enable it automatically. To return to manual
startup, disable the unit and stop it while the container is idle:

```sh
sudo systemctl disable --now oneplus6t-waydroid-session.service
```

The unit is intentionally pinned to the stock `greetd` UID 114 and
`wayland-0` socket used by this phone. On a different compositor/user, copy a
drop-in with `systemctl edit` and change `User`, `Group`, `HOME`,
`XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` and `DBUS_SESSION_BUS_ADDRESS` together;
do not start a second session from SSH at the same time. If the SSH daemon is
already wedged, run the disable/restart or enable operation from the phone's
local terminal, not through the stalled SSH channel.

### Repair stale recording-profile mappings

The profile synchronizer is a separate, smaller transaction for an image that
already has the camera provider installed. First stop the Waydroid session and
container, then run the same health preflight used above and require
`rootfs_mounts=0` and `overlay_precondition=pass`:

```sh
pmos-sync-waydroid-camera-profiles --dry-run
sudo pmos-sync-waydroid-camera-profiles
```

The apply command copies the repository's mapping to both profile filenames,
prints the backup directory and writes an SHA-256 manifest. It does not reboot
the phone, alter a partition or touch the camera provider. Start the container
and session again, then run the Camera2 `encode-720p` probe on IDs 0 and 1.
To undo the exact change, use the printed backup path while Waydroid is
stopped:

```sh
sudo pmos-sync-waydroid-camera-profiles \
  --rollback /var/lib/waydroid/backups/camera-profiles-YYYYMMDDTHHMMSSZ-PID
```

Never edit either overlay file while Waydroid's rootfs is mounted. The helper
is intentionally explicit so a normal postmarketOS update cannot silently
rewrite or partially apply a lower-layer overlay transaction; rerun it after
an image/profile update and retain its printed backup for rollback.

The ID 2 sentinel is required by the Android framework rather than by the
camera provider. AOSP's `MediaProfiles` code builds its required-profile table
using the numeric camera ID as an array-like index; a sparse profile set such
as 0 and 1 reaches its `CHECK` for a missing ID 2. The checked-in
`highspeedcif` entry keeps that table contiguous, while the probe confirms that
ID 2 has no ordinary low/high/480p/720p profile. Do not turn the sentinel into
an ordinary encoder profile unless auxiliary Venus teardown has been repaired.
See the corresponding
[AOSP MediaProfiles implementation](https://android.googlesource.com/platform/frameworks/av/+/014a9ed60d/media/libmedia/MediaProfiles.cpp#714).

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

## r44 camera streams and r50-r53 Venus hardware encoding

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

Patch `0001` keeps camera input DMA-BUF zero-copy, uses MMAP only for the small
compressed V4L2 capture buffers, validates their offset/length and copies each
encoded payload into Codec2. Patch `0002` then preserves the real Venus NV12
allocation layout and DMA-BUF lifetime and destroys the encoder before the
input-format converter. Patch `0003` reads the stride of the temporary graphic
allocation directly from Codec2 gralloc metadata. It deliberately does not
map/import that throwaway block, because the phone's minigbm/Mesa combination
crashed while freeing the mapped allocation. The series is pinned to Android
source commit `6cf3be6acb0e321459172ec12824f448e1c14b9e`; its patch hashes are:

```text
0001: 0a70f1c34f44918eea3080cd081906f3a0584c099d440502f93823398390658b
0002: b3435cfb9751e01c5255d34960de789dd2395536ba37b3f6e76947a703c19a29
0003: 6944ead29cd27f44eed605c18156f31bd50df5b625c7e6dcdb1eafacfae8864c
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

That historical cadence matched the approximately 18.96 fps delivered by the
rear camera source and was materially above the 11.37 fps software control.
The lens faced a dark surface during both recordings, so it was an encoder-path
control rather than colour acceptance.

The first layout/lifetime candidate fixed the visible green lower band and the
dangerous destruction order, but its first real CameraX start exposed a
different pre-encode crash. The Codec2 tombstone placed a null dereference in
Mesa `gbm_bo_unmap`, reached while `getVideoFrameStride()` destroyed a mapped
temporary `C2GraphicBlock`. No frame had reached Venus and no Venus/SMMU fault
or IRQ storm occurred. Patch `0003` is the narrowly scoped correction for that
failure; it leaves real recording-buffer mapping and conversion unchanged.

Codec2 r53 was built twice from clean source/build paths and packaged twice;
the stages and archives are byte-identical. It was installed with Waydroid
stopped and unmounted. Three guarded Aperture start/stop cycles passed,
including a force-stop and cold activity relaunch. Every cycle reached an H.264
keyframe, started the muxer, emitted `VideoRecordEvent Finalize` and reported a
successful MediaStore URI. There was no Codec2 tombstone, fatal signal,
Venus/SMMU/session error, IRQ storm, I/O pressure, D-state task or stale rootfs
mount. IRQ activity returned to zero immediately after each encoder teardown.

The first private illuminated file decoded from beginning to end and probes as:

```text
video: H.264 yuv420p, 720x1278 portrait, nominal 30000/1001 fps,
       measured 11.620796 fps
audio: AAC mono, 48000 Hz
container: 23.836600 s, 29354988 bytes
```

Frames at 5 and 15 seconds show the complete image without the former green
layout band. They also confirm that the open image remains softer/foggier than
the vendor camera. The 11.62 fps measured cadence is still too low despite the
nominal rate; frame-rate optimization, longer clips, app switching and
suspend/resume remain required. The later r50 work below accepts front
recording and deliberately disables auxiliary Venus recording.

### Reproduce the hardware encoder

The preparation helper fetches seven exact Android source revisions from
`android.googlesource.com` and applies all three patches. The build requires Android
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
  /tmp/codec-stage /tmp/oneplus6t-waydroid-v4l2-codec-r53
```

Both output directories must be absent or empty. Two complete builds from
different source and output paths produced byte-identical staged files. The
packager normalizes order, ownership and timestamps; two package runs are also
byte-identical. The currently installed reproducible r53 hashes are:

```text
source result: 4f4a6d5d4c28794f76e4eff4a53c2b3bb6652458
archive: 61707f4726f03e49d26e45bcfd184630e8c28e6410400fe8e327d16f84d14073
manifest: 26a21d4c439a772370f76c564ef2a72977e06b2f87c229405ea4ac7bd072691c
service: df13a5a1792ea657405dbac0d5d95d3345ee12ca229cd4f69699809300e9a8d8
plugin: eb61890494acee634529634a154faed923b2b77813ab7b2da0ff8c09f9db63f6
common: ed62f247b6788474557c8af2165dc813cc746ba47c07234600e667ea5ba4e225
components: 0b193b76851701f3d9cfce5c4be5e705429dd14036403a2761994b8218deb73c
```

The exact archive and manifest are published in the
[r53 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-v4l2-codec-r53).
Downloading both assets again produced byte-identical files and the hashes
above.

The older r51 archive remains published as historical reproducibility evidence,
but it lacks the r52 layout/lifetime work and r53 initialization fix and must
not replace r53 on the reference phone. To install a freshly reproduced r53,
first stop both the Waydroid session and container and require an unmounted
rootfs with zero PSI I/O pressure. Extract the archive into an empty staging
directory, verify its manifest, then run:

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

The previous r50 foreground-session interruption remains useful safety
evidence: never force an overlay install through a mounted-rootfs or I/O-
pressure gate. The r53 acceptance stopped the activity, user session and
container in order, reached `rootfs_mounts=0`, restored the temporary greeter
socket permissions and ended with zero D-state tasks and zero I/O pressure.

## r49 contiguous NV12 GPU acceptance

Date: 2026-08-28. Patch `0016` replaces the compatible Waydroid NV12 path's
RGBA readback plus CPU libyuv conversion with one GPU render target. The target
spans the contiguous Y and UV planes as `DRM_FORMAT_GR88`; one fragment writes
two luma bytes in the upper rows or one interleaved chroma pair in the lower
rows. The shader retains five-tap luma sharpening and a true four-sample 2x2
chroma average. Separate backing objects, unexpected offsets, import/FBO
failure or a GL error disable this path and return to the accepted conversion
fallback instead of failing a request.

The performance probe was first run as a matched r44/r48 A/B with Aperture
stopped and the already-installed probe reused between samples. Three r44 runs
reported 12.14, 12.27 and 12.14 Camera2 capture fps (mean 12.18), while the
equivalent direct-path prototype reported 12.61, 12.91 and 12.81 fps (mean
12.78). Camera-provider CPU time fell from 1.033 to 0.930 CPU-seconds per run.
That is about 4.9% higher source cadence and 10.0% less provider CPU in this
bounded scene; it is not a general camera or battery benchmark.

The accepted source was then squashed into one patch and stripped of two
unused experimental plane shaders. A fresh ARMv7/API-33 build completed all
198 targets. The exact r49 build ran three more `record-yuv-720p` probes; all
returned valid RGB and YUV, and the provider logged the contiguous DMA-BUF path
for every run. Its capture samples were 11.61, 13.45 and 12.96 fps (mean 12.67)
with 0.977 provider CPU-seconds per run. No readback fallback, provider crash,
Venus/SMMU fault, IRQ storm or safety-monitor fault occurred.

A real r49 Aperture recording also finalized normally and decoded from start
to end:

```text
video: H.264 yuv420p, 720x1278 portrait, 293 frames over 24.863678 s,
       measured 11.784258 fps
audio: AAC mono, 48000 Hz, 24.806812 s
container: 24.928500 s, 30912234 bytes
```

Frames at 5 and 20 seconds retained the complete image, stable colour and no
green stride/layout band. Final encoded cadence is still effectively the same
11-12 fps class as r44/r48; the measured improvement is in Camera2 source work
and provider CPU, not Android-vendor video-frame-rate parity. The remaining
haze, fine grid and colour/tone gap require sensor calibration and image-
pipeline tuning rather than another NV12 layout conversion.

```text
0016 patch: 6d5e283d7b9a775100fec91f72c8e9474becf15dd7de320b0ce267148e7f1057
r49 archive: 2b969ddd79df780b865962dd3dfa568b6b64a94fc6766a02c8dcefd6128a85d7
r49 manifest: 8edaf8117e14f1ea134ec5a198bc7bff0d1ed30671c717da6ecd963cba4b3998
camera.libcamera.so: 8d6d714bb1449cf3ffb42f66708a053f50c1e5c83c62890ca6b3c1cc9e6fec49
libcamera.so: a9a52464f750989112537daa92706cbeb41553d63c06eeaa978a86c984cdd5ca
```

The exact archive and manifest are published in the
[r49 development pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r49-contiguous-nv12).
Downloading both assets again produced the hashes above.

## r50 mapped post-processor fence acceptance

Date: 2026-08-28. The r49 direct NV12 path correctly returned a native GPU
completion fence to Android, but Camera3 started mapped YUV/JPEG
post-processors from the same source immediately. Main rear happened to finish
before the CPU read it; front and auxiliary JPEGs reproducibly contained
horizontal green/static rows. A decoded-row regression metric counted 0, 56
and 119 large full-width discontinuities for camera IDs 0, 1 and 2.

Patch `0017` gathers the unique sources required by mapped post-processors in
`CameraDevice::requestComplete()`, waits once on each source fence and then
dispatches the workers. It does not make direct-only streams synchronous. It
also prevents two mapped consumers from racing `FrameBuffer::releaseFence()`.
The standalone patch applies cleanly after exact r49, passes libcamera
checkstyle and has a dedicated source/order regression test.

A clean ARMv7/API-33 build from commit
`0c2bc9359e68216917875556b02b33a07d606d05` completed all 198 targets. The exact
archive was installed through the guarded camera installer. A complete run of
all three Camera2 cameras then passed YUV, JPEG, private preview, AF and EV.
All three JPEGs decoded with `jpegRowJumps=0/24`; their maximum adjacent-row
changes were 6.1, 4.2 and 7.1 respectively. No private photographs are stored
in the repository or release.

A real front-camera Aperture recording also finalized and decoded end to end:

```text
video: H.264 yuv420p, 1280x720 with portrait rotation metadata,
       453 frames over 18.2898 s, measured about 24.77 fps
audio: AAC mono, 48000 Hz, 18.170896 s
container: 18.2898 s, 21930400 bytes
```

Frames sampled during that private clip have normal colour and no purple or
horizontal corruption. This accepts front-camera encode correctness, not
vendor image-quality parity. Main rear remains accepted by r49/r50; a direct
auxiliary-camera encoder is unsafe. Both recorder-first and Android's
session-before-recorder shutdown order reproduced a delayed Venus recovery
IRQ storm after stop, while an exact main-rear control passed. The probe now
hard-refuses that combination, and the safety generation omits ID 2 recording
profiles without changing its preview/YUV/JPEG support.

```text
0017 patch: 9150f64910f24432d46e19621b4c0c5861fda7d5ea8a32f1cabdb4e7ddeae3c2
r50 archive: cec3c2ed3fc2b7c23f55ad6e2458cea1af0fc07281d2d358650e4f0142c99979
r50 manifest: 2b54fb7e403b9d58d94746870d70b359d1c0fce3de1cafd6b46d9c541890bc9b
camera.libcamera.so: 59937d1d950ad9c6602453cdb616fa066a6988aedbf8c798666e3a0838fa245d
libcamera.so: 61eee82f2cbd1a78241a424ef496e4601d412d1e754a7d2507f6fc923aa0f7b3
```

## r51 auxiliary-video safety acceptance

The r51 bundle is a minimal safety generation: every compiled camera runtime
file is byte-identical to accepted r50, while both Android recording-profile
files are replaced with the reviewed configuration from this repository. IDs
0 and 1 retain conservative 480p/720p H.264/AAC profiles. ID 2 is omitted so
CameraX and legacy applications cannot select the Venus path that produced the
delayed post-stop IRQ storm. Its preview, YUV and JPEG streams are unchanged.

The archive was packaged twice from a clean exact-r50 stage and both outputs
were byte-identical. It was installed through the guarded helper, which created
the rollback directory
`/var/lib/waydroid/backups/camera-20260828T134626Z-7563`. After restart, a
three-camera preview probe ended `PROBE_DONE profile=preview valid=3 total=3`.
Legacy and API-31 profile queries found valid profiles for IDs 0/1 and returned
`has=false all=false` for every tested quality on ID 2. A one-second safety
monitor recorded no Venus/SMMU fault or IRQ growth. The session and container
then stopped normally with zero rootfs mounts, zero D-state tasks and zero
current PSI I/O pressure.

```text
r51 archive: 04355331ac5a8b4559f3df68e7a3d65094ea083e0f50b9fe7b8b580c34442e63
r51 manifest: b06633944db7347be6174fd6529130cb056138fd6f7cc4318449e00c7d04815e
media_profiles.xml: 7f0eb36f586893d9a2906dba08b2352f78a8a58f2c162acd8bf38d84aca8fc10
camera.libcamera.so: 59937d1d950ad9c6602453cdb616fa066a6988aedbf8c798666e3a0838fa245d
libcamera.so: 61eee82f2cbd1a78241a424ef496e4601d412d1e754a7d2507f6fc923aa0f7b3
```

Download the archive and manifest from the
[r51 auxiliary-video safety release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r51-aux-video-safety),
verify both hashes above, extract into a new empty staging directory and run
the guarded installer only while the Waydroid session and container are
stopped. Do not substitute the older r50 profile files.

## r52 clean-Vanilla acceptance

The GAPPS-to-Vanilla migration exposed a packaging dependency that an in-place
r51 upgrade could not reveal. The old Waydroid tree already contained a
32-bit legacy provider and both host camera properties; a fresh ARM64 Vanilla
image did not. The framework therefore had no usable camera provider even
though every project-built Camera3 library was present.

The r52 release includes the four verified provider files, VINTF manifest
and the existing 16 r51 runtime files. The guarded installer now manages 21
runtime files, sets exactly one `ro.hardware.camera=libcamera` line in both
host property files, and saves their exact originals beside the overlay
backup. Its fixture test performs a real install and rollback, proving that an
old provider/property state is restored and newly introduced targets are
removed.

The source provider came from the hash-verified official Waydroid ARM
2025-06-28 MAINLINE vendor image. Its accepted file hashes are:

```text
provider service: 289d25aac2976c7846f7d1ab5190fc13518bd7818220422c4e159a35f3058034
provider implementation: 4afca5a19384f1f988918245dcf36e7a4a8862880fb70119c65f6f3cacd1c06c
legacy provider module: 06ee026271182a55e28f765dca4edd8111b839eca61d5532d575a9a076cc0c8a
camera.device implementation: 94fa320d31e441de2d9af4ce2fe18ec9ffddc6f38fe41754737021a064eefcd2
VINTF manifest: cdd30a3f1792b9408f0d55850fc5453dca16e39fcafa252005dba881cc07b982
r52 archive: 57a7f015461c2c5a3544401592307de78d5b991c3ac78b21eecb9d8662b8652e
r52 manifest: 5c5ee54715a1d0e71cb4f6cbda1878969c360d1fa9858dc5c3d80c54eb001f25
```

Those exact files are published in the
[r52 clean-Vanilla camera pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r52-vanilla-complete).

On the clean accepted Vanilla image, Android reports the provider `running`,
the external provider with zero devices and the intended legacy provider with
three devices. Isolated Camera2 `preview` and displayed `surface` profiles
passed on IDs 0, 1 and 2. IDs 0/1 delivered roughly 1.6–1.8 displayed FPS;
ID 2 reached 9.0 displayed FPS while its ImageReader diagnostic path was 2.2
FPS. This confirms the user's Waydroid preview lag and places the main
bottleneck in the provider/software-ISP path rather than a universal
SurfaceFlinger limit. All three surface samples covered full RGB range, and no
kernel, IOMMU, GPU, Venus, provider or Android fatal event followed the runs.

These are functional and diagnostic results, not image-quality or Android
performance parity. A private face/colour-chart comparison and full JPEG run
remain required. Hardware encoding on camera ID 2 remains prohibited.

## r53 Camera3 worker-lifecycle candidate and static9 runtime

Date: 2026-08-29. The live r52 provider passed the sequential diagnostic, but
the broader intermittent `stream error` report pointed to a second lifecycle
boundary in the shared Android HAL. `Camera::stop()` completes libcamera
requests synchronously; its YUV/JPEG post-processors, however, run on separate
workers. Before this patch, `CameraDevice::stop()` could clear request
descriptors and streams while one of those workers still held a descriptor.
That late completion could corrupt the next configure/open attempt.

Patch `0018` drains every post-processor before clearing descriptors or streams.
For Android `flush()`, it drains the workers and restarts them after keeping
the configured streams, preserving stream reuse. It also completes a pending
Camera3 descriptor as an error at the stop boundary, supplies a monotonic
fallback when the simple V4L2 path reports a zero sensor timestamp, keeps that
timestamp identical in shutter and result metadata, and marks error-buffer
results with their final metadata partial-result value. The existing
frame-duration `std::clamp` call is explicit for `int64_t`, which keeps the
Android source portable on host ABIs where `int64_t` is `long`.

The patch applies cleanly after the complete r52 source tree, passes
`git diff --check`, and the Android HAL target compiles in a clean host Meson
build. Its SHA-512 is:

```text
0018 patch: 0dd2918e36cf71333f01354959e46b1b2359286796d2a6dd747a2f107cab349f5fa540146d3cfd8df9e2da2f69506fcd29248fe35acef8900916e7e2d8b3529d
```

The static9 runtime archive was installed through the guarded provider
installer after creating a dated rollback backup. Its reproducibility hashes
are:

```text
archive: c64c04242692eb2279b2e579805bef2fefcc65b7453e5830d8c46aba216fdd38
vendor/lib/hw/camera.libcamera.so: da9f5c3bb75fc62b56a607c7774f27eb0cfb3ff49cf1276672118b6ff52742d7
```

The latest runtime evidence is:

- five consecutive ID-0 preview open/close cycles, followed by two rounds of
  IDs 0/1/2, all returned valid frames and exited with status 0;
- one full YUV+JPEG+private-preview probe for each ID returned
  `PROBE_DONE valid=1 total=1`; and
- `dumpsys media.camera` reported `In-flight requests: None` after each latest
  full probe and after the stress runs.

An earlier first ID-0 full probe left one diagnostic in-flight frame after the
application exited; a clean repeat and the remaining full probes were clear.
This is why the overlay is accepted for the reproducible diagnostic path but
ordinary camera applications still need a real open/close soak before the
intermittent stream-error issue can be called fully closed.

## r53-static10-focus manual-focus checkpoint

The follow-up provider archive is
`/tmp/waydroid-camera-r53-static10-focus.tar.gz` during the reference build;
its SHA-256 is
`c5a805378cecc2bca656b44fcdd06e5414951394e503ab713aa9aaa73767f174`.
It includes the Android `0019` bridge, the r28 simple IPA and the current
sensor tuning. It was installed over the guarded r53 provider without changing
the Android image or native `/usr/lib`.

The reproducible probe results were:

```text
CAMERA id=0 valid=true profile=manual-focus privateFrames=24 manualFocusSupported=true manualFocusDistanceMax=2.000 manualFocusResult=[0.000,2.000] manualFocusDelta=2.000
CAMERA id=1 valid=true profile=manual-focus privateFrames=12 manualFocusSupported=false manualFocusDistanceMax=0.000 manualFocusResult=[NaN,NaN] manualFocusDelta=NaN
CAMERA id=2 valid=true profile=manual-focus privateFrames=24 manualFocusSupported=true manualFocusDistanceMax=2.000 manualFocusResult=[0.000,2.000] manualFocusDelta=2.000
PROBE_DONE profile=manual-focus valid=3 total=3
```

The matching `tap-focus` run returned terminal rear AF states `[3,4]` and
non-empty center regions on IDs 0 and 2; the fixed-focus front ID 1 remained
`afMode=0` with no region. These results prove Android request/result routing
and actuator movement. They do not prove a factory-calibrated distance scale,
vendor colour tuning or ordinary third-party camera-app acceptance.

## Rollback

Stop the Waydroid session and container, then pass the exact backup directory
printed by the installer to the rollback command:

```sh
sudo scripts/install-waydroid-camera --rollback \
  /var/lib/waydroid/backups/camera-YYYYMMDDTHHMMSSZ-PID
sudo waydroid container start
waydroid session start
```

The script restores every backed-up file and both host property files to their
exact prior state and removes only overlay targets explicitly recorded as
absent before installation.
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
- Compatible contiguous Android NV12 allocations use the r50 direct GPU path.
  Other layouts still use synchronous RGBA readback followed by CPU NV12
  conversion; use the probe and provider log to distinguish the two paths.
- Running the probe while Aperture or another camera client owns CAMSS can
  produce a transient media-link-busy result; stop camera clients and rerun the
  probe before treating it as a regression.
- Camera2 numeric IDs are provider enumeration details; applications should
  use facing/characteristics rather than assuming a fixed number.
- Auxiliary preview, YUV and JPEG remain enabled, but its recording profile is
  intentionally absent. Two bounded hardware-encoder attempts caused the same
  post-stop Venus recovery IRQ storm with both recorder-first and Android's
  session-first teardown order. Do not restore that profile merely to expose a
  video button; use a proven non-Venus encoder or fix the kernel/Codec2 path.
- Play Store installation, GPS and the Waydroid location bridge are separate
  roadmap items. They are not claimed by this camera patch.
