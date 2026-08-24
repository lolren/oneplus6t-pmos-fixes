# Waydroid Camera2 probe

This small, dependency-free Android application verifies the Camera3 HAL from
the Camera2 API that ordinary Android applications use. It is a diagnostic,
not a replacement camera application, and it never uploads a frame.

## What it verifies

For every camera reported by Android, the probe checks:

- Camera2 characteristics can be read without malformed-metadata assertions;
- a 640x480 YUV stream produces non-flat luminance and chroma data;
- an implementation-defined preview stream continues to deliver frames;
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

The preceding `CAMERA` records contain per-camera stream, autofocus, exposure
and SHA-256 evidence. Generated JPEGs remain in the application's private
directory. Do not add them to Git.

## Remove

```sh
waydroid app remove dev.lolren.waydroidcameraprobe
```

Removing the probe does not alter the HAL, native camera packages or Waydroid
overlay.
