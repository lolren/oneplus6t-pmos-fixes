# Camera stack

This repository contains a reproducible camera stack for the OnePlus 6T
(`oneplus-fajita`) on postmarketOS. It covers all three sensors, both rear
focus actuators, software-ISP scaling, exposure defaults and the controls that
the current open pipeline can implement honestly.

Kernel r8, libcamera/IPA r20, `pipewire-spa-libcamera` r6 and Snapshot r2 are
installed on the reference phone. The complete userspace set was built for
aarch64, hash-verified, simulated offline and installed without a reboot. Exact
r19/r5/r1 packages are retained as the rollback baseline. Nothing in this work
flashes a partition, changes a boot slot or reboots the phone.

## Hardware map

Use the stable media-path camera IDs in scripts. `/dev/v4l-subdev*` numbers can
change after a kernel or media-graph change.

| Camera | Stable libcamera ID | Focus hardware |
| --- | --- | --- |
| Rear main, IMX519 | `/base/soc@0/cci@ac4a000/i2c-bus@0/camera@1a` | LC898217XC actuator |
| Rear secondary, IMX376 | `/base/soc@0/cci@ac4a000/i2c-bus@1/camera@10` | LC898217XC actuator |
| Front, IMX371 | `/base/soc@0/cci@ac4a000/i2c-bus@0/camera@10` | Fixed focus; no actuator |

The tested actuator control range is `0..2047`. The useful contrast-focus
range for the reference phone is approximately `400..800`; raw DAC units are
not calibrated optical dioptres.

## Included fixes

### Front Quad Bayer mode

The IMX371 full readout repeats each colour over a physical 2x2 block:

```text
R R G G
R R G G
G G B B
G G B B
```

Advertising that as ordinary RGGB makes a conventional demosaic nearly
monochrome and creates a regular grid. Kernel patches add the sensor's
2304x1728 hardware-binned mode and its 399 MHz link frequency. The sensor then
combines each same-colour block and emits ordinary RGGB without a proprietary
remosaic stage.

### Gain conversion and exposure

IMX371, IMX376 and IMX519 use:

```text
gain = 1024 / (1024 - register_code)
```

The libcamera helpers convert register codes to real gain and provide the
10-bit black level. Kernel patches expose the intended 16x gain range on
IMX371 and IMX376 instead of the previous approximately 1.88x limit.

The main IMX519 1280x720 and 1920x1080 modes are capable of 120 and 60 fps,
but the simple pipeline does not request a frame duration. It therefore used
those maximum rates for ordinary preview, limiting exposure to about 4.2 ms
or 16.7 ms. The kernel patch keeps those maximum rates while making 30 fps the
default. This permits substantially longer exposure and lower gain until the
pipeline gains an explicit `FrameDurationLimits` implementation.

### Highlight-aware exposure and open tone defaults

The previous AGC considered only a coarse raw-luminance mean. A frame could
therefore satisfy that target while red or blue clipped after automatic white
balance multiplied the channel. The software ISP now gathers separate linear
red, green and blue histograms. When enabled by tuning, AGC predicts the
brightest post-white-balance channel quantile and constrains the ordinary mean
correction to keep it below a configurable target.

The OnePlus tuning protects the 98th percentile at 0.95 on all three sensors.
This is a highlight constraint, not HDR: it changes sensor exposure/gain but
does not merge frames or tone-map an extended range. Omitting both new keys
preserves the old AGC behavior; specifying only one or an out-of-range value is
rejected.

The generic `Adjust` algorithm also accepts tuned defaults while retaining the
normal libcamera controls as application overrides:

| Sensor | Gamma | Contrast | Saturation | Sharpness |
| --- | ---: | ---: | ---: | ---: |
| Front IMX371 | 2.0 | 1.10 | 1.25 | 1.0 |
| Secondary IMX376 | 2.1 | 1.05 | 1.15 | 1.0 |
| Main IMX519 | 2.2 | 1.05 | 1.25 | 1.0 |

These are conservative open tone/detail defaults selected from bounded
captures. Sharpness 1 applies a restrained five-tap unsharp mask; 0 disables
it and 2 is the supported maximum. The
CCMs remain identity matrices because no colour chart, calibrated illuminants
or flat field were available. Android/vendor matrices were inspected only as
private diagnostic evidence and are not copied, redistributed or represented
as compatible calibration.

### Rear autofocus

The simple IPA gains contrast-detect autofocus for both rear cameras:

- standard `AfModeAuto` and `AfModeContinuous` modes;
- standard `AfTriggerStart` and `AfTriggerCancel` input;
- standard `AfMetering` and sensor-coordinate `AfWindows` input;
- `AfStateIdle`, `Scanning`, `Focused` and `Failed` metadata;
- a central two-dimensional Sobel focus statistic normalized by luminance;
- coarse and fine scans with actuator settling and measurement windows;
- centre selection across the near-peak focus plateau, avoiding edge bias;
- continuous-focus hysteresis and delayed restart after a sustained contrast
  loss; and
- no autofocus controls on fixed-focus IMX371.

The tuning scans DAC positions `400..800`, first in steps of 100 and then 25.
Positions within 10% of the peak metric form a plateau, and the selected
position is its centre. `LensPosition` is deliberately not advertised: the
kernel value is an uncalibrated DAC code, while libcamera defines that control
in dioptres. Advertising a knowingly false unit would break applications.

### Snapshot tap-to-focus and still resolution

Tap-to-focus is implemented through the normal application stack rather than
through a phone-specific actuator command:

1. libcamera exposes `AfMetering` and `AfWindows` and evaluates focus statistics
   only inside the requested sensor rectangle;
2. PipeWire transports rectangle-array controls and publishes the maximum
   sensor crop, effective stream crop and libcamera orientation after format
   negotiation; and
3. Snapshot removes letterboxing from the tap, maps it through the effective
   crop and inverse orientation, then atomically sends `AfModeAuto`, window
   metering, one focus rectangle and `AfTriggerStart`.

Snapshot shows a focus marker only after the helper accepts the request. Eight
seconds later it restores continuous autofocus. Camera changes and stale async
callbacks clear the marker safely. The fixed-focus front camera has no AF
controls and is rejected without showing false success.

Snapshot preview remains inexpensive. For a still, it separately selects the
largest 4:3 mode not exceeding 2048x1536, avoiding the previous behavior where
the preview-sized stream also limited the saved picture.

### GPU grid and crop fix

The old EGL path demosaiced and resized packed Bayer data in one pass with
nearest-neighbour source sampling. Non-integer downscales aliased the Bayer
phase into a visible horizontal/vertical grid. A CPU-path comparison removed
the grid but center-cropped most of the view and used more CPU, so it was kept
only as a diagnostic.

The final EGL path:

1. demosaics to an intermediate full-resolution RGB texture;
2. builds a mipmapped low-pass pyramid;
3. center-crops to the requested aspect ratio; and
4. scales filtered RGB into the output buffer.

AGC, AWB and autofocus statistics use the same centered source rectangle as
the displayed image. The 2304x1728-to-800x600 test sustained 30 fps on the
Adreno 630 and removed the regular grid while retaining the full field of
view.

### User controls

An identity CCM enables a truthful saturation control without pretending that
the sensors have been colour-chart calibrated. The tested controls are:

| Feature | Main rear | Secondary rear | Front | Status |
| --- | --- | --- | --- | --- |
| Automatic exposure | Yes | Yes | Yes | Corrected gain models plus per-channel highlight protection |
| Automatic white balance | Yes | Yes | Yes | Existing simple AWB |
| Continuous autofocus | Yes | Yes | No hardware | Added and live-tested in isolation |
| One-shot autofocus | Yes | Yes | No hardware | Trigger/state sequence tested |
| Tap-to-focus | Yes | Yes | No hardware | Snapshot sensor-region transport live-tested |
| Contrast | Yes | Yes | Yes | `0..2` |
| Gamma | Yes | Yes | Yes | `0.1..10` |
| Saturation | Yes | Yes | Yes | `0..2`; 0 and 2 endpoints tested |
| Sharpness | Yes | Yes | Yes | `0..2`; 0, default 1 and 2 tested |
| Full-frame still mode | 2048x1536 | 2048x1536 | 2048x1536 | Snapshot caps selection and live negotiation tested |
| HDR | No | No | No | No valid merge/tone-map implementation |
| Flash integration | No | No | No | LEDs exist but are not a libcamera flash device |
| Manual exposure/AWB | No | No | No | Not implemented by the simple IPA |
| Calibrated CCM/LSC | No | No | No | Requires chart and flat-field calibration |
| Temporal denoise | No | No | No | No equivalent algorithm in this pipeline |

The IMX371 and IMX376 kernel drivers contain wide-dynamic-range register
hooks. That is not Android-style HDR: the software ISP cannot merge the
resulting exposures or tone-map them. Enabling the register switch and naming
it HDR would return invalid or unmerged data, so `HdrMode` remains absent.

Android parity also includes proprietary tuning, calibrated lens shading,
temporal denoise, multi-frame fusion and scene processing. The open stack is
materially improved but those missing stages prevent an honest claim of exact
Android image parity.

## Patch layout

Kernel patches targeting `sdm845-mainline/linux` tag
`sdm845-7.1-rc1-r0` are in
`patches/linux-postmarketos-qcom-sdm845/`:

1. IMX371 2304x1728 binned mode;
2. OnePlus device-tree link frequency;
3. IMX371 16x gain range;
4. IMX376 16x gain range; and
5. IMX519 30 fps preview defaults.

The thirteen-patch libcamera 0.7.2 series is in
`patches/libcamera/v0.7.2/`. Sensor tuning files are in
`config/libcamera/simple/`. The PipeWire 1.6.8 transport patch and Snapshot
50.0 two-patch application series have their own versioned directories under
`patches/`. The single pmaports integration diff in `packaging/pmaports/` adds
all patches, tuning, checksums and package revision bumps.

No APK, private photograph, raw capture, device identifier, Android camera
library or vendor tuning blob is committed.

## Reproducible build

Use the reviewed pmaports base and verify the integration diff before applying
it:

```sh
git checkout 875bddba6538818f2c3c9849e184f40688ad5140
git apply --check --whitespace=nowarn /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
git apply --whitespace=nowarn /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch

pmbootstrap -p "$PWD" build --arch aarch64 libcamera
pmbootstrap -p "$PWD" build --arch aarch64 pipewire
pmbootstrap -p "$PWD" build --arch aarch64 snapshot
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

The reference build produced `libcamera`/`libcamera-ipa` r20,
`pipewire-spa-libcamera` r6, Snapshot r2 and the existing SDM845 kernel r8.
See `packaging/pmaports/README.md` for hashes and rollback rules. These commands
build packages only.

## Validation

All camera processes were bounded, captures remained private and both rear
lenses were parked at DAC 0 after tests.

- Both rear continuous-AF tests selected position 600 and reached `Focused`.
- A one-shot main-camera test reported 240 frames in `Scanning` followed by 60
  in `Focused`, with no restart.
- A forced-defocus continuous test detected sustained metric loss, rescanned
  once and returned to the prior focus plateau without hunting.
- Saturation 0 produced zero measured chroma; saturation 2 increased measured
  chroma relative to the default.
- Sharpness 0, the tuned default 1 and maximum 2 produced ordered edge and
  Laplacian detail signals in a staged front-camera scene. Default 1 was kept
  because it improved detail without the visibly stronger maximum treatment.
- The installed PipeWire node published effective crop
  `1368,1042,1920,1440`, maximum crop `1048,1042,2560,1440` and orientation 6
  for a 640x480 main stream. The installed Snapshot helper accepted focus and
  reset on both rear cameras. The main lens physically moved from parked DAC 0
  to DAC 400; the fixed-focus front returned the expected unsupported result.
- Main, secondary and front nodes each negotiated three bounded 2048x1536
  frames through PipeWire.
- The r18 filtered front-camera runtime completed a bounded 30-frame
  800x600 capture from the 2304x1728 input at approximately 30 fps.
- With the same staged scenes in separate bounded runs, average chroma changed
  from 10.1 to 13.3 on the front, 23.4 to 34.1 on the main and 24.5 to 27.1 on
  the secondary. Near-clipped pixels changed from 9.20% to 0.03%, 0.12% to
  0.01% and 2.15% to 0.13%, respectively. These are regression metrics, not
  colour-chart calibration.
- During a physical low-power flash step, main-camera gain moved from 16.0 to
  4.70 and recovered to 16.0. The secondary moved from 66.4 ms at gain 2.51 to
  34.1 ms at gain 1.0, then recovered to its starting exposure product.
- A private front-camera threshold test converged to measured highlight 0.4998
  for a 0.50 target. Restoring production tuning raised exposure smoothly,
  confirming that the front path regulates too.
- Legacy tuning retained gamma 2.2, contrast 1, saturation 1 and disabled the
  new highlight constraint. Malformed pairings and invalid adjustment ranges
  were rejected.
- Repeated captures on all three sensors completed without EGL, CSI or camera
  process errors in both isolated and installed tests.
- The full native libcamera test run had 48 passes, one expected failure, 30
  hardware skips and no failures. PipeWire passed 52 of 52 tests. Clean
  aarch64 package builds completed for libcamera r20, PipeWire r6 and Snapshot
  r2.

The retained r8 plus r19/r5/r1 package set is the rollback baseline. The
reference phone now runs kernel r8 with the validated r20/r6/r2 userspace
packages.

## Installation boundary

Do not unload camera modules on a running phone. A kernel package replaces
modules under the current release path, so after any approved kernel upgrade
do not open the camera or load modules before the approved reboot. The current
revision is userspace-only and did not require a kernel upgrade or reboot.

To reproduce the completed installation safely:

1. retain exact copies or verified rebuilds of the prior r19 libcamera, r5
   PipeWire plugin and r1 Snapshot packages;
2. stage patched and rollback APKs in separate offline repositories;
3. place the noarch Snapshot language APK in the indexed `aarch64` repository
   alongside the four aarch64 APKs;
4. run `apk upgrade --simulate` and require exactly five upgrades and no
   removal;
5. record the exact-version rollback command and a hash of `/etc/apk/world`;
   and
6. close camera applications before installation. No reboot is needed for
   this userspace-only revision.

Never use `apk upgrade --available` against a partial camera repository. It can
remove unrelated installed packages.

## References

- [Sony Quad Bayer coding](https://www.sony-semicon.com/en/technology/mobile/quad-bayer-coding.html)
- [SDM845 mainline IMX371 driver](https://gitlab.com/sdm845-mainline/linux/-/blob/sdm845-7.1-rc1-r0/drivers/media/i2c/imx371.c)
- [libcamera simple software ISP](https://git.libcamera.org/libcamera/libcamera.git/tree/src/libcamera/software_isp)
- [libcamera autofocus controls](https://libcamera.org/api-html/namespacelibcamera_1_1controls.html)
