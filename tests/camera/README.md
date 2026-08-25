# Camera control fixtures

These are libcamera `cam --script` fixtures used for bounded camera-stack
validation.

- `af-auto-trigger.yaml` selects `AfModeAuto` and sends one
  `AfTriggerStart` request.
- `af-continuous.yaml` selects `AfModeContinuous` for a bounded capture.
- `saturation-zero.yaml` requests monochrome output through saturation 0.
- `saturation-double.yaml` requests saturation 2.
- `sharpness-zero.yaml` disables the software-ISP unsharp mask.
- `sharpness-double.yaml` requests its maximum supported strength. Compare
  either only against an identically framed and illuminated capture.
- `tone-balanced.yaml` requests the front/main tone candidate explicitly.
- `tone-balanced-af-continuous.yaml` combines that request with continuous AF.
  These two fixtures override tuning controls and are diagnostics, not sensor
  calibration or the secondary camera's production defaults.
- `ppm-metrics.py` reports luma, average channel spread, HSV-style saturation,
  near-clipping percentages and two luma-detail signals from private binary
  PPM captures. Edge and Laplacian values are scene-dependent and are valid
  only for like-for-like framing, lighting and resolution.
- `run-light-step.sh` performs a bounded, low-power rear-camera flash step with
  unconditional LED-off and lens-park cleanup.
- `capture-portal-screenshot.py` asks the desktop screenshot portal for one
  private PNG, verifies that the response belongs to its request and accepts
  only a local file URI. It is used to compare visible UI state before and
  after a gesture; captures remain ignored by Git.
- `uinput-touch.py` emits exactly one bounded tap or two-finger pinch through a
  temporary direct-touch uinput device. It tears the device down after normal
  exit, errors and interruptions, and never opens a physical input device.
- `validate-pipewire-af.sh` discovers the current PipeWire serials, verifies a
  real central-target tap-focus and scan-free Reset on both rear modules, holds
  each in continuous mode to detect hunting, and confirms that the fixed-focus
  front rejects autofocus while still streaming. Its default `required` mode
  demands generation-correlated `focused` results from r7/r1; `accepted` mode
  is reserved for validating an intentional r6/r0 rollback.
- `analyze-light-step.py` summarizes exposure metadata from that test.

Example with a separately staged libcamera runtime:

```sh
R=/path/to/runtime
export LD_LIBRARY_PATH="$R/usr/lib"
export LIBCAMERA_IPA_MODULE_PATH="$R/usr/lib/libcamera/ipa"
export LIBCAMERA_IPA_PROXY_PATH="$R/usr/libexec/libcamera"
export LIBCAMERA_IPA_CONFIG_PATH="$R/usr/share/libcamera/ipa"

"$R/usr/bin/cam" \
  --camera '/base/soc@0/cci@ac4a000/i2c-bus@0/camera@1a' \
  --capture=300 \
  --stream role=still,width=1600,height=1200,pixelformat=ABGR8888 \
  --script=tests/camera/af-auto-trigger.yaml \
  --metadata
```

Run only one camera process at a time. After actuator diagnostics, close the
camera and park the corresponding lens at 0 with
`scripts/v4l2-focus-control.py`. Do not assume `/dev/v4l-subdev*` numbers are
stable across boots or kernel revisions; resolve the media graph first.

For an installed tap-to-focus stack, discover the current PipeWire serial by
matching `api.libcamera.path` in `gst-device-monitor-1.0 Video/Source`. While a
bounded stream to that serial is active in one terminal, submit a normalized
focus point in another:

```sh
camera_serial=DISCOVERED_SERIAL

timeout 20 gst-launch-1.0 -q \
  pipewiresrc target-object="$camera_serial" \
  ! 'video/x-raw,format=RGBA,width=640,height=480,colorimetry=sRGB' \
  ! fakesink sync=false
```

```sh
/usr/libexec/advanced-snapshot-focus-control focus \
  "$camera_serial" 0.50 0.50 0.18
/usr/libexec/advanced-snapshot-focus-control reset "$camera_serial"
```

With r7/r1 the helper must print exactly `focused` for either rear node and an
unsupported result for fixed-focus IMX371. A low-detail target may truthfully
return `failed`; use a detailed central target for acceptance. Stop the stream
before parking the dynamically matched actuator. The serial is ephemeral and
must never be copied into a patch or script.

The complete r24 transition/stability check runs unattended as the graphical
login user. Close camera applications first, or explicitly allow the runner to
close Snapshot:

```sh
tests/camera/validate-pipewire-af.sh \
  --output /private/path/af-validation \
  --stability-seconds 60 \
  --focus-result required \
  --close-camera-apps
```

It temporarily enables selective `IPASoftAf` logging and restarts only the
user's PipeWire/WirePlumber services. If the desktop portal was active, the
runner stops both it and its wlroots backend before each PipeWire cycle and
restores both afterward, avoiding a stale camera-portal connection. A trap
restores any prior libcamera log
environment and active services on success, error or interruption. The test
does not need root, capture an image, alter a kernel module or reboot.

Measure a final PPM without publishing it:

```sh
tests/camera/ppm-metrics.py /private/path/final.ppm
```

On the OnePlus 6T itself, with no other camera process running, a rear light
step can be reproduced without root:

```sh
tests/camera/run-light-step.sh \
  --runtime "$R" \
  --camera '/base/soc@0/cci@ac4a000/i2c-bus@0/camera@1a' \
  --output /private/path/light-step

tests/camera/analyze-light-step.py \
  /private/path/light-step/main-light-step.log \
  /private/path/light-step/main-light-step.markers
```

The runner accepts only the two known rear camera IDs, uses LED levels 32/16
out of 255 for three seconds, and traps normal exit or interruption to turn
both channels off and park the matched actuator at DAC 0. Captures and full
logs remain private and are ignored by this repository.

For a bounded graphical pinch acceptance test, install `grim` (used by the
Phosh portal backend) and `py3-gobject3`, keep Advanced Snapshot focused, and
run the helper with the phone's virtual input dimensions. Root is required
only to open `/dev/uinput`:

```sh
python3 tests/camera/capture-portal-screenshot.py \
  /private/path/zoom-before.png

sudo python3 tests/camera/uinput-touch.py \
  --width 1080 --height 2340 \
  pinch --center-x 0.50 --center-y 0.50 \
  --start-span 0.18 --end-span 0.55

python3 tests/camera/capture-portal-screenshot.py \
  /private/path/zoom-after.png
```

The acceptance condition is a larger zoom chip value and a visibly cropped
preview in the second image. Restore the display lock after unattended tests.
Use `--dry-run` to inspect the generated coordinates without opening uinput.
