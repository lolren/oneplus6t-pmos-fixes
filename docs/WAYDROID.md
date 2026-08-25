# Waydroid camera support

This document covers the open-source Camera3 path used by Android 13 in
Waydroid on the OnePlus 6T. It uses the mainline kernel cameras and libcamera's
software ISP. It does not copy OnePlus/OxygenOS camera libraries, calibration
blobs or firmware.

The reference phone runs Waydroid 1.6.3 with an ARMv7 mainline vendor image.
The r24 overlay is installed and exposes three Android cameras. The native
postmarketOS stack is packaged separately; see [CAMERA.md](CAMERA.md).

## Features and their benefit

| Feature | What it brings |
| --- | --- |
| Three-camera enumeration | Android applications can open the main rear, secondary rear and front sensors instead of seeing no camera provider. |
| Camera location and rotation map | Camera2 receives the correct front/back role and display orientation for each stable media path. |
| minigbm plane parsing | The HAL reads Waydroid's real buffer offsets, strides and sizes, preventing corrupt mappings and one-plane assumptions. |
| Software NV12 output | The mainline software ISP can fill Android YUV and implementation-defined preview buffers without a proprietary ISP HAL. |
| YUV, JPEG and private streams | Preview, analysis and still-capture paths used by ordinary Camera2 applications all return data. |
| Valid low-frame-rate metadata | A camera whose usable mode is below 30 fps remains in Android's stream map instead of causing malformed Camera2 characteristics. |
| Variable 15–30 fps preview | In low light, applications may allow a frame to grow to about 66.7 ms for more exposure; a fixed 30 fps video request stays fixed. |
| Exposure compensation | Camera2 -1 to +1 EV requests reach libcamera and the applied value returns in capture results. |
| Exposure result metadata | Exposure time, sensor sensitivity and frame duration let applications understand what automatic exposure actually selected. |
| Rear autofocus bridge | Camera2 auto/continuous modes, triggers, states and one metering region reach both physical rear actuators. |
| Bounded explicit focus scan | Tap-focus does not spend hundreds of frames traversing the entire actuator range; it uses a fast bounded scan and local refinement. |
| Fixed-focus reporting | The front camera honestly advertises no autofocus instead of accepting controls that cannot move hardware. |
| Automated Camera2 probe | A reproducible APK verifies every stream, AF state and exposure path without depending on a store camera application. |

These are lower-layer camera features. They do not add a polished Android
camera UI by themselves; an Android camera application consumes them.

## Source layout

- `patches/libcamera/v0.7.2/` contains the sixteen generic native patches. The
  final two add `FrameDurationLimits` and stable progressive autofocus
  transitions to simple-pipeline sensors.
- `patches/libcamera/waydroid/v0.7.2/` contains the Android-only Camera3 HAL
  patch. Apply it after the complete generic series.
- `config/waydroid/camera_hal.yaml` maps stable OnePlus media paths to Android
  facing and rotation values.
- `config/waydroid/init.oneplus6t-camera.rc.in` is the provider override. Its
  `@VIDEO_GID@` placeholder must become the numeric postmarketOS `video` GID.
- `scripts/build-waydroid-camera` creates a clean Android ARMv7 libcamera build
  and runtime staging tree.
- `tests/waydroid-camera-probe/` builds the validation APK.

The Android patch depends on the generic frame-duration and autofocus work. It
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
the Android patch:

```sh
git clone https://gitlab.freedesktop.org/camera/libcamera.git libcamera-waydroid
cd libcamera-waydroid
git checkout v0.7.2

git am /path/to/patched-pmaports/temp/libcamera/0001-*.patch
git am /path/to/patched-pmaports/temp/libcamera/0002-*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/v0.7.2/*.patch
git am /path/to/oneplus6t-pmos-fixes/patches/libcamera/waydroid/v0.7.2/*.patch
```

Stop if any patch rejects. Do not use `--3way` to hide a source-version
mismatch. The reviewed order ends with generic frame duration, generic
autofocus-transition stability and then the Android Camera3 commit.

## Build a runtime bundle

Choose new, empty build and stage directories:

```sh
export ANDROID_NDK_ROOT=/path/to/Android/Sdk/ndk/29.0.14206865
export WAYDROID_DEPS_PREFIX=/path/to/android-armv7-dependencies
export ANDROID_API=33

/path/to/oneplus6t-pmos-fixes/scripts/build-waydroid-camera \
  /path/to/libcamera-waydroid \
  /path/to/build-waydroid-camera \
  /path/to/stage-waydroid-camera
```

The helper configures only the simple pipeline/IPA and generic Android HAL,
builds for ARMv7, signs the IPA with the build-local key, installs under the
staging `vendor/` tree, adds `libc++_shared.so`, and installs the reviewed
OnePlus tuning and camera map. The generated IPA private key remains in the
build directory and must not be committed.

At minimum, retain these runtime files together:

```text
vendor/etc/libcamera/camera_hal.yaml
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
```

Do not mix a HAL from one build with a library or signed IPA from another.

## Install into the Waydroid overlay

First render the provider configuration on the phone. The reference
postmarketOS `video` group is GID 27, but another installation must resolve its
own value:

```sh
video_gid=$(getent group video | cut -d: -f3)
test -n "$video_gid"
sed "s/@VIDEO_GID@/$video_gid/" \
  config/waydroid/init.oneplus6t-camera.rc.in \
  > /tmp/init.oneplus6t-camera.rc
```

Create a dated backup outside the overlay. Preserve every existing target and
record which targets were absent before installation. Then stop only Waydroid:

```sh
sudo waydroid session stop
sudo waydroid container stop
```

Copy the runtime files to the same relative paths below
`/var/lib/waydroid/overlay/`, and install the rendered provider file as:

```text
/var/lib/waydroid/overlay/system/etc/init/init.oneplus6t-camera.rc
```

Shared objects, YAML and the signature may be mode 0644; executable helpers
must be mode 0755. Keep root ownership. The provider override runs as Android's
`cameraserver`, adds the host video GID so it can open the mainline media
devices, and writes bounded diagnostic logs to
`/data/local/tmp/libcamera-provider.log` inside Android.

Start the container as root and the session as the normal login user:

```sh
sudo waydroid container start
waydroid session start
```

This operation does not alter a partition, boot slot, kernel or firmware and
does not require a phone reboot.

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

The final r24 run on 24 August 2026 verified all three YUV/JPEG/private stream
sets. Both
rear cameras reported autofocus states `[3, 4]`; the front reported fixed
focus `[0]`. All cameras returned -1/0/+1 EV metadata and visible pixel
movement. The result file SHA-256 was
`425a0525ed08c039cba6831b0ec9c6566bec0ebbb1d7b03267b16f71feac2483`.
Generated photographs remain private and are not part of the repository.

Reference runtime hashes were:

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
The rendered provider fragment was also installed beside the existing
Waydroid init overlay and tested through a complete container/session restart.
Android boot completed, the provider retained supplementary GID 27, and all
three camera devices returned closed and available without an init override
error.

The r24 installation first copied all thirteen replaced targets into a dated
rollback tree with a presence manifest and SHA-256 file. The native Android
probe then returned `PROBE_DONE valid=3 total=3`: camera IDs 0 and 2 reported
AF states `[3, 4]` with real metering regions, camera 1 reported fixed-focus
state `[0]`, and every camera passed YUV, private preview, JPEG, EV and sensor
timing checks. The Waydroid Android session was returned to its prior stopped
state afterward; the container service remained active. The complete r23
overlay backup remains the immediate Android rollback.

## Rollback

Stop the Waydroid session and container, restore every backed-up file to its
original relative overlay path, and remove only targets explicitly recorded as
absent before installation. In particular, remove
`init.oneplus6t-camera.rc` only when the backup record proves it was newly
created. Start the container/session again and require the prior camera count
and provider state.

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
- The Android framework logged a recoverable JPEG blob-footer warning and
  occasional close/flush timeout during the automated stress probe. All three
  JPEGs decoded and all cameras reopened, but broader third-party-app testing
  is still required.
- Camera2 numeric IDs are provider enumeration details; applications should
  use facing/characteristics rather than assuming a fixed number.
- Play Store installation, GPS and the Waydroid location bridge are separate
  roadmap items. They are not claimed by this camera patch.
