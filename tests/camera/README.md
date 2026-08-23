# Camera control fixtures

These are libcamera `cam --script` fixtures used for bounded camera-stack
validation.

- `af-auto-trigger.yaml` selects `AfModeAuto` and sends one
  `AfTriggerStart` request.
- `saturation-zero.yaml` requests monochrome output through saturation 0.
- `saturation-double.yaml` requests saturation 2.

Example with a separately staged libcamera runtime:

```sh
R=/path/to/runtime
export LD_LIBRARY_PATH="$R/usr/lib"
export LIBCAMERA_IPA_MODULE_PATH="$R/usr/lib/libcamera/ipa"
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
