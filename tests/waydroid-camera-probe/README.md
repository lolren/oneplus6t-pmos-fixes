# Waydroid Camera2 probe

This small, dependency-free Android application verifies the Camera3 HAL from
the Camera2 API that ordinary Android applications use. It is a diagnostic,
not a replacement camera application, and it never uploads a frame.

## What it verifies

For every camera reported by Android, the probe checks:

- Camera2 characteristics can be read without malformed-metadata assertions;
- legacy `CamcorderProfile` and API-31+ `EncoderProfiles` availability is
  logged for 2160p, 1080p, 720p, 480p, high, low and QVGA qualities;
- a 640x480 YUV stream produces non-flat luminance and chroma data;
- an implementation-defined preview stream continues to deliver frames at a
  common useful size (an older 1600x1200 mode when present, otherwise the r44
  1280x960 cap or its 1280x720 recording peer); and
- private-preview frame timestamps are reported so before/after source-mode
  performance can be compared without treating FPS as a pass/fail claim;
- a `TextureView` surface-only run counts frames reaching the displayed Android
  viewfinder, separating presentation/compositor throughput from provider
  delivery, and takes one asynchronous RGB pixel sample for channel-order
  evidence; and
- a Camera2 `TEMPLATE_RECORD` run uses the Android recording request template
  on the displayed `TextureView`, preferring an advertised fixed 30 FPS range
  when available, so video-template/compositor throughput can be compared with
  the ordinary preview template without creating a video file; and
- a `record-yuv-720p` run adds the real 1280x720 YUV consumer used by the
  recording path, isolating full-size NV12 production from the encoder and
  muxer; surface/compositor timing is reported separately from Camera2 sensor
  result timing, exposure and frame duration; and
- an `encode-720p` run records ten seconds through a real Camera2
  `MediaRecorder` surface, then requires a non-empty 720p H.264 video track and
  AAC microphone track before reporting success; and
- a JPEG request produces a decodable, non-empty image without repeated
  full-width row discontinuities from an unsignalled GPU source fence;
- rear autofocus accepts a sensor-region request and reports scan/focus states;
- the `tap-focus` profile submits a real center metering rectangle with an
  Android `AF_TRIGGER_START` request and waits for a terminal rear focus state;
- the `manual-focus` profile switches each rear camera between 0 and its
  advertised minimum-focus distance and verifies that `LENS_FOCUS_DISTANCE`
  changes in capture results; fixed-focus cameras are reported as unsupported;
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

Grant the requested Camera permission. The encoded profile also needs the
Microphone permission. Leave the phone still while the probe works through all
cameras. A large software-ISP preview can run at only a few frames per second,
so the complete exposure sequence can take up to about twenty minutes. The
activity closes itself when finished.

Camera2 device closure is asynchronous. The probe stops repeating requests,
aborts pending captures, closes the device, and waits for
`CameraDevice.StateCallback.onClosed()` before releasing its ImageReader and
recorder surfaces or opening the next camera. This ordering is intentional: it
keeps the diagnostic from creating a false stream-drain failure by
reconfiguring the next camera while the previous one is still closing. A
bounded timeout records the close problem instead of hanging forever.

Read the private result from the host:

```sh
waydroid shell -- cat \
  /data/user/0/dev.lolren.waydroidcameraprobe/files/result.txt
```

A complete pass ends with:

```text
PROBE_DONE valid=3 total=3
```

The preceding `CAMERA` records contain per-camera stream, private-preview
size, `privateFps`, `privateIntervalMs`, autofocus, exposure and SHA-256
evidence. The normal preview profiles report timestamps from an `ImageReader`
and describe provider-delivered buffers; they are not a display-latency
measurement. The `surface` profile reports `privateTimingSource=surface`,
counts `TextureView` update callbacks, and adds fields such as
`surfaceRgbMean=[r,g,b]` and `surfaceRgbRange=[r,g,b]` from one asynchronous
readback. It also saves that sampled displayed frame as
`surface-camera-<id>.png` in the application's private directory. This
includes the Android surface/compositor path and provides evidence for RGB
channel ordering or an all-black surface, but it is not a colour-chart or
image-quality pass/fail test. Generated JPEGs and PNGs remain in the
application's private directory. Encoded MP4s are private too. Do not add any
of them to Git.

## Performance profiles

The default `full` profile intentionally exercises the complete validation
load: private preview, YUV analysis, JPEG capture, autofocus and exposure
checks. That is useful for acceptance, but it is not an apples-to-apples
preview benchmark because several streams are active at once.

Use the Android activity extra to isolate the preview path:

```sh
# Private/implementation-defined preview only
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile preview

# Private preview plus YUV analysis, without JPEG
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile preview-yuv

# Real Android TextureView presentation path, without ImageReader analysis
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile surface

# TextureView presentation plus a YUV consumer, like preview plus analysis
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile surface-yuv

# Camera2 recording template plus the real Android TextureView path
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile record

# Same record template and TextureView plus a 1280x720 YUV consumer
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile record-yuv-720p

# Real 720p H.264/AAC recording (main rear ID 0 or front ID 2 only)
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile encode-720p --es camera-id 0

# Camera2 metering rectangle plus AF_TRIGGER_START (rear autofocus)
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -W -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile tap-focus

# Verify the standard Camera2 manual-focus control on a rear camera (ID 0 or 1)
waydroid shell -- am force-stop dev.lolren.waydroidcameraprobe
waydroid shell -- am start -W -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity \
  --es profile manual-focus --es camera-id 1
```

After installing this repository, the same operation can be run and saved
with one host command:

```sh
pmos-run-waydroid-camera-probe build/waydroid-camera-probe.apk preview \
  /tmp/oneplus6t-camera-preview.txt
```

Use `preview-yuv`, `full`, `tap-focus`, or `manual-focus` as the second argument for the
other profiles.
Use `surface` to measure updates reaching a real Android `TextureView`,
`surface-yuv` to add a simultaneous YUV consumer, or `record` to use Camera2's
`TEMPLATE_RECORD` while measuring that same displayed surface. Use
`record-yuv-720p` to add the full-size NV12 consumer without invoking Codec2.
It prefers fixed 30 FPS when the camera advertises it and records the selected
range in the result. The `record` and `record-yuv-720p` profiles remain
unencoded diagnostics. Use `encode-720p` for a bounded real H.264/AAC test.
That profile deliberately leaves Camera2's AE target range unset, allowing the
camera timestamps and the per-camera `CamcorderProfile` to negotiate cadence.
It also follows Android's recording teardown order: stop and close the capture
session before stopping `MediaRecorder`, so no new DMA-BUFs race Codec2
`STREAMOFF`.
Use `manual-focus` with rear camera ID 0 or 1 to verify that Android's standard
focus-distance request reaches the rear actuator. The profile sends 0.0 D and
the advertised maximum distance in separate repeating requests, waits for
each request to settle, and requires a result-distance delta of at least 0.25
D. A fixed-focus camera is reported as `manualFocusSupported=false` rather than
treated as a failure. This checks control transport and actuator movement; it
does not claim that every scene has the same optical sharpness.

Use `tap-focus` with rear camera ID 0 or 1 to verify the separate Camera2 tap-style
path. It sends a center `CONTROL_AF_REGIONS` rectangle together with
`CONTROL_AF_TRIGGER_START` and requires `FOCUSED_LOCKED` or
`NOT_FOCUSED_LOCKED` before passing. This validates Android request routing and
state reporting; it remains a transport test, not a colour-chart or lens
calibration claim.

To copy the generated MP4 to a new host path, isolate one camera and set the
media-output variable:

```sh
PMOS_WAYDROID_PROBE_CAMERA_ID=0 \
PMOS_WAYDROID_PROBE_MEDIA_OUTPUT=/tmp/oneplus6t-camera-0.mp4 \
PMOS_WAYDROID_PROBE_ALLOW_ENCODER=yes \
  pmos-run-waydroid-camera-probe \
  build/waydroid-camera-probe.apk encode-720p \
  /tmp/oneplus6t-camera-0-encode.txt
```

The runner refuses to overwrite either output. Keep captures private unless
every person and object in view is safe to publish. The explicit allow flag is
intentional: encoded diagnostics exercise camera, Codec2 and kernel teardown
together and must run only after the Waydroid health and safety-monitor gates.
Camera ID 1 (the auxiliary rear module) is hard-disabled for this profile: two bounded attempts with
different teardown ordering both caused a Venus recovery IRQ storm after stop.
Its preview, YUV and JPEG profiles remain enabled; auxiliary video must use a
non-Venus encoder until that kernel/Codec2 incompatibility is fixed.

The runner streams the APK directly to Android's package manager, avoiding a
dependency on Waydroid's host-side copy/install helper. It grants the camera
and microphone permissions, stops any previous
probe instance, clears only the probe's old generated result, waits for
`PROBE_DONE`, and refuses to overwrite an existing host result file. The runner
allows twenty minutes for `full` and eight minutes for the shorter profiles.
Set `PMOS_WAYDROID_PROBE_TIMEOUT` to override that limit. For repeated matched
performance runs, set `PMOS_WAYDROID_PROBE_SKIP_INSTALL=yes` after the first
successful install; the runner verifies that the package exists, but avoids an
unnecessary Package Manager update between samples. To isolate one
numeric Camera2 ID during diagnosis, set `PMOS_WAYDROID_PROBE_CAMERA_ID`, for
example:

```sh
PMOS_WAYDROID_PROBE_CAMERA_ID=1 \
  pmos-run-waydroid-camera-probe build/waydroid-camera-probe.apk full \
  /tmp/oneplus6t-camera-1-full.txt
```

Read `result.txt` after the activity exits. A performance run ends with a
profile-qualified summary such as:

```text
PROBE_DONE profile=preview valid=3 total=3
```

Compare `privateFps` and `privateIntervalMs` between `preview` and
`preview-yuv`, then compare both with `full`. If `preview` is fast but `full`
is slow, the extra stream/conversion load is the limiting factor. If `preview`
is already slow, compare it with `surface` and `record`: a lower surface rate
points to Waydroid's surface/compositor path, while a drop only in `record`
points to the Android recording template or its negotiated stream. When all
three are slow, the Camera3 provider, software ISP or device mode is the
likely boundary. These measurements do not replace visual latency review, but
they make the Android preview boundary repeatable without relying on a
particular camera application. Surface timing samples are coalesced before
dispatch to the camera worker, preventing a backlog of UI callbacks from
inflating the reported rate.

For a repeatable before/after report, save two results from the same profile
and run:

```sh
pmos-compare-waydroid-camera-probes \
  /tmp/oneplus6t-preview-r35.txt \
  /tmp/oneplus6t-preview-r37.txt
```

The comparison checks that the same camera IDs are present and valid, then
prints each camera's FPS change, interval, timing source and any
`surfaceRgbMean`/`surfaceRgbRange` fields. It deliberately does not decide
that a faster result has acceptable image quality; keep or roll back a
candidate only after the visual, JPEG and lifecycle checks in
`docs/VALIDATION.md`.

The profile extra is diagnostic only. An unknown value safely falls back to
`full`, and the default command remains the complete acceptance probe.

## Remove

```sh
waydroid app remove dev.lolren.waydroidcameraprobe
```

Removing the probe does not alter the HAL, native camera packages or Waydroid
overlay.
