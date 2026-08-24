# Camera control fixtures

These are libcamera `cam --script` fixtures used for bounded camera-stack
validation.

- `af-auto-trigger.yaml` selects `AfModeAuto` and sends one
  `AfTriggerStart` request.
- `af-continuous.yaml` selects `AfModeContinuous` for a bounded capture.
- `saturation-zero.yaml` requests monochrome output through saturation 0.
- `saturation-double.yaml` requests saturation 2.
- `tone-balanced.yaml` requests the front/main tone candidate explicitly.
- `tone-balanced-af-continuous.yaml` combines that request with continuous AF.
  These two fixtures override tuning controls and are diagnostics, not sensor
  calibration or the secondary camera's production defaults.
- `ppm-metrics.py` reports luma, average channel spread, HSV-style saturation
  and near-clipping percentages from private binary PPM captures.
- `run-light-step.sh` performs a bounded, low-power rear-camera flash step with
  unconditional LED-off and lens-park cleanup.
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
