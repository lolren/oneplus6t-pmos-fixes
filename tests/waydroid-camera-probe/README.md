# Waydroid Camera2 probe

This small, dependency-free Android application verifies the Camera3 HAL from
the Camera2 API that ordinary Android applications use. It is a diagnostic,
not a replacement camera application, and it never uploads a frame.

## What it verifies

For every camera reported by Android, the probe checks:

- Camera2 characteristics can be read without malformed-metadata assertions;
- a 640x480 YUV stream produces non-flat luminance and chroma data;
- an implementation-defined preview stream continues to deliver frames at a
  common large size (preferably 1600x1200, then 1920x1080); and
- private-preview frame timestamps are reported so before/after source-mode
  performance can be compared without treating FPS as a pass/fail claim;
- a JPEG request produces a decodable, non-empty image;
- rear autofocus accepts a sensor-region request and reports scan/focus states;
- the fixed-focus front camera reports autofocus as unavailable;
- -1, 0 and +1 EV requests are returned in capture metadata;
- exposure time, sensitivity and frame duration metadata are present; and
- exposure compensation either changes measured pixels or reaches a documented
  sensor exposure/gain limit.

The last distinction matters in a very dark scene. `evPixelMovement=true`
means the requested compensation visibly changed the sampled Y plane.
`evSensorLimited=true` means the positive request was accepted but the sensor
was already at its tested exposure/gain ceiling. Neither result claims Android
vendor-HAL image processing.

## Build requirements

- a JDK providing `javac`, `jar` and `keytool`;
- `zip`;
- Android SDK platform 34; and
- Android SDK build-tools 36.0.0.

Set `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) and run:

```sh
ANDROID_SDK_ROOT="$HOME/Android/Sdk" ./build.sh
```

Override `ANDROID_PLATFORM` or `ANDROID_BUILD_TOOLS_VERSION` only when the
matching SDK files are installed. The output is
`build/waydroid-camera-probe.apk`. The build directory, APK and generated local
debug key are ignored by Git; no shared signing key is stored in this project.

## Install and run

Start Waydroid as the normal login user, then run:

```sh
waydroid app install build/waydroid-camera-probe.apk
waydroid app launch dev.lolren.waydroidcameraprobe
```

Grant the one requested Camera permission. Leave the phone still while the
probe works through all cameras; low-light stabilization can make a complete
run take about three minutes. The activity closes itself when finished.

Read the private result from the host:

```sh
waydroid shell cat \
  /data/user/0/dev.lolren.waydroidcameraprobe/files/result.txt
```

A complete pass ends with:

```text
PROBE_DONE valid=3 total=3
```

The preceding `CAMERA` records contain per-camera stream, private-preview
size, `privateFps`, `privateIntervalMs`, autofocus, exposure and SHA-256
evidence. The timing fields describe frames delivered to the Camera2 reader;
they are not a display-latency measurement and do not claim image-quality
parity. Generated JPEGs remain in the application's private directory. Do not
add them to Git.

## Performance profiles

The default `full` profile intentionally exercises the complete validation
load: private preview, YUV analysis, JPEG capture, autofocus and exposure
checks. That is useful for acceptance, but it is not an apples-to-apples
preview benchmark because several streams are active at once.

Use the Android activity extra to isolate the preview path:

```sh
# Private/implementation-defined preview only
waydroid shell am force-stop dev.lolren.waydroidcameraprobe
waydroid shell am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile preview

# Private preview plus YUV analysis, without JPEG
waydroid shell am force-stop dev.lolren.waydroidcameraprobe
waydroid shell am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile preview-yuv
```

After installing this repository, the same operation can be run and saved
with one host command:

```sh
pmos-run-waydroid-camera-probe build/waydroid-camera-probe.apk preview \
  /tmp/oneplus6t-camera-preview.txt
```

Use `preview-yuv` or `full` as the second argument for the other profiles.
The runner installs the APK, grants its camera permission, stops any previous
probe instance, waits for `PROBE_DONE`, and refuses to overwrite an existing
result file. Set `PMOS_WAYDROID_PROBE_TIMEOUT` when the phone is especially
slow.

Read `result.txt` after the activity exits. A performance run ends with a
profile-qualified summary such as:

```text
PROBE_DONE profile=preview valid=3 total=3
```

Compare `privateFps` and `privateIntervalMs` between `preview` and
`preview-yuv`, then compare both with `full`. If `preview` is fast but `full`
is slow, the extra stream/conversion load is the limiting factor. If `preview`
is already slow, the bottleneck is in the Camera3 provider, software ISP,
Waydroid compositor or device mode rather than JPEG validation. These profiles
measure buffers delivered by Camera2, not the number of frames visible on the
screen; use a camera-app recording or screen capture for display latency.

The profile extra is diagnostic only. An unknown value safely falls back to
`full`, and the default command remains the complete acceptance probe.

## Remove

```sh
waydroid app remove dev.lolren.waydroidcameraprobe
```

Removing the probe does not alter the HAL, native camera packages or Waydroid
overlay.
