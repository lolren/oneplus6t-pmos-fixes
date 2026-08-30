# Camera stack

This repository contains a reproducible camera stack for the OnePlus 6T
(`oneplus-fajita`) on postmarketOS. It covers all three sensors, both rear
focus actuators, software-ISP scaling, exposure defaults and the controls that
the current open pipeline can implement honestly.

The current reference phone runs kernel r10, libcamera/IPA r31,
`pipewire-spa-libcamera` r8, Snapshot r3 and Advanced Snapshot r32. The r30/r8
lower layer and r32 app were built for AArch64 and installed without a reboot;
r31 is the same lower-layer control stack with the sensor-specific colour
profiles described below. Both r30 and r31 remain reproducible rollback
generations.
Both rear modules now expose bounded manual `LensPosition` control as well as
contrast-detect autofocus; the fixed-focus IMX371 is explicitly excluded from
focus controls. All three sensors expose standard automatic/manual white
balance plus a standard writable colour matrix. The exact r24/r25/r26/r28/r29
and PipeWire r7 packages plus earlier app generations remain
rollback and diagnostic evidence. Installing r10 through `apk` ran the normal
postmarketOS trigger that updated the active boot image; no bootloader, slot
metadata or firmware was changed, and that reboot was a separate action.

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

The main IMX519 1280x720 and 1920x1080 modes are capable of 120 and 60 fps.
Before explicit timing control, ordinary preview could inherit those rates and
limit exposure to about 4.2 ms or 16.7 ms. The kernel patch keeps those maximum
rates while making 30 fps the default.

Libcamera r23 introduced `FrameDurationLimits` when the sensor exposes
VBLANK. A client may request a range down to a conservative 15 fps, allowing a
frame of about 66.7 ms in low light. The mode default is unchanged until a
client requests a range, and a fixed-rate video request stays fixed. VBLANK is
applied before exposure because the V4L2 exposure limit grows only after frame
length changes. Active frame duration is returned in request metadata.

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
| Front IMX371 | 2.0 | 1.10 | 1.35 | 1.0 |
| Secondary IMX376 | 2.1 | 1.10 | 1.35 | 1.0 |
| Main IMX519 | 2.2 | 1.10 | 1.35 | 1.0 |

These are conservative open tone/detail defaults selected from bounded
captures. Sharpness 1 applies a restrained five-tap unsharp mask; 0 disables
it and 2 is the supported maximum.

The r31 downstream package also ships sensor-specific 3×3 colour matrices for
IMX371, IMX376 and IMX519, selected by the estimated colour temperature. They
are represented as ordinary libcamera YAML in `config/libcamera/simple/` and
were recovered as numeric transforms from the matching stock sensor tuning.
They are useful interoperability defaults, not a measured factory calibration:
there is no accompanying colour-chart, illuminant, lens-shading or flat-field
measurement. The profile test checks the entry counts, ordering and sentinels;
rebuilding the package from this repository reproduces the exact data without
shipping a vendor binary. Android/vendor processing remains outside this open
pipeline.

The simple AGC also exposes the standard `ExposureValue` control from -1 to +1
EV. It shifts both the configured histogram target and the protective
per-channel highlight ceiling by the same power of two, then reports the active
value in request metadata. Zero EV preserves the original highlight policy;
positive EV deliberately trades highlight headroom for brightness instead of
being cancelled by a fixed ceiling. This is exposure compensation, not fixed
manual shutter control.

The simple IPA also exposes standard manual shutter and analogue-gain controls.
`ExposureTime` is expressed in microseconds at the libcamera API boundary and
converted to sensor line units internally; `AnalogueGain` is a linear multiplier
converted through the sensor helper. Requests are clamped to the active V4L2
ranges, and the corresponding Auto/Manual modes are returned in metadata. The
application sends both controls atomically and restores both automatic modes
together. This is a real manual control path, but it is not a vendor-calibrated
ISO implementation and it does not implement HDR.

### Rear autofocus

The simple IPA gains contrast-detect autofocus for both rear cameras:

- standard `AfModeAuto` and `AfModeContinuous` modes;
- standard `AfTriggerStart` and `AfTriggerCancel` input;
- standard `AfMetering` and sensor-coordinate `AfWindows` input;
- `AfStateIdle`, `Scanning`, `Focused` and `Failed` metadata;
- a central two-dimensional Sobel focus statistic normalized by luminance;
- a progressive local coarse scan centred on the last successful position,
  extending toward an edge only while measurements justify it;
- a bounded fine scan, configurable actuator settling and final-position
  validation;
- centre selection across the near-peak focus plateau, avoiding edge bias;
- continuous-focus hysteresis and delayed restart after a sustained contrast
  loss;
- slow downward adaptation of the continuous-focus reference so one noisy
  peak cannot cause recurring false scene changes;
- a sustained-rise filter that requires three consecutive high-contrast
  windows before promoting the reference, with only a conservative 20% step
  toward the lowest candidate window;
- scan-free return from tap-focus to continuous monitoring at the selected
  physical lens position; and
- no autofocus controls on fixed-focus IMX371.

The allowed range remains DAC `400..800`, with coarse step 100, fine step 25
and two settle frames. A cold start begins at 600; later scans begin around the
last focused position and expand only toward a better edge. Tap-focus uses the
same bounded search with faster measurements. Positions within 10% of the peak
metric form a plateau, and the selected position is its centre.

The r28 simple IPA also advertises `LensPosition` as a bounded device contract
from `0.0` (far end) to `2.0` (near end). It linearly maps that public range to
the measured safe DAC span `400..800`, publishes the normalized position in
metadata and holds the selected actuator in `AfModeManual`. This is not a
factory-calibrated object-distance/dioptre table; the normalized range is used
because the available hardware evidence does not justify claiming one.
Reset submits `AfModeContinuous` without a forced full-range scan.

The r28 build includes the sustained-rise filter (`monitorReferenceRiseWindows: 3`
and `monitorReferenceRise: 0.2`) on the IMX376 and IMX519. A single bright
or unusually detailed frame can therefore not raise the long-lived reference;
three consecutive 250 ms monitor windows are required, and the reference
moves only 20% toward the least extreme candidate window. Downward adaptation
and a sustained contrast-loss restart remain unchanged. The deterministic
`tests/test-af-reference.py` model covers the isolated-spike, sustained-rise,
sustained-loss and transient-loss boundaries.
On the installed r28 stack, both rear modules completed local searches and the
manual 0.0-to-2.0 sweep. A 60-second native validation for each rear module
returned metadata-confirmed `focused` and recorded zero post-reset lens
requests or autofocus restarts. The exact summary is recorded in the current
validation entry below.

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

Snapshot r3 draws a complete yellow focus square immediately so touch feedback
is never hidden behind PipeWire discovery. Advanced Snapshot r24 handles the
tap on the Camera ancestor in capture phase, maps it through the negotiated
crop/orientation, and keeps one-shot autofocus at the selected position after
the metadata-confirmed result. Its preview now has a labelled **Controls**
overlay button; the hamburger menu retains **Image Controls** as a fallback.
**Reset** explicitly returns to continuous
autofocus; there is no delayed reset that can blur a subsequent still. Camera
changes and stale async callbacks clear the marker safely. The fixed-focus
front camera has no AF controls and is rejected without claiming focus
success.

The Image Controls panel also exposes Gamma and the Camera Calibration dialog.
The dialog stores standard exposure, white-balance gains, an optional 3×3
colour matrix, tone/detail and optional manual-focus values under a stable
physical-sensor identity, so the IMX371, IMX376 and IMX519 profiles remain
separate. It is a repeatable userspace control profile, not a source of
Android's factory matrix coefficients, lens shading or multi-frame ISP tuning.

Advanced Snapshot's stricter result path is packaged separately. PipeWire r7
publishes an accepted-trigger generation and correlates it with real
`AfState` request metadata. The app keeps its reticle amber while waiting,
turns it green only for a metadata-confirmed `Focused` state and red for
`Failed` or a transport error. It refuses to invent success when used with the
older r6 transport.

Snapshot preview remains inexpensive. For a still, it separately selects the
largest 4:3 mode not exceeding 2048x1536, avoiding the previous behavior where
the preview-sized stream also limited the saved picture.

### Explicit rear LED flash pulse

The OnePlus 6T exposes its rear illumination as two LED class channels,
`white:flash` and `yellow:flash`, rather than as a libcamera flash control. The
repository therefore installs the bounded `pmos-camera-flash` helper for an
explicit application request:

```sh
pmos-camera-flash --status
pmos-camera-flash --pulse --duration-ms 2500 --level 32
```

`--status` and `--probe` are read-only. A pulse uses only writable top-level
`*:flash` channels, saves their current brightness, caps the duration at five
seconds, halves the requested level for yellow/amber channels, and restores
every saved value on normal completion or interruption. `--off` is available
for an explicit zeroing operation. Advanced Snapshot keeps the control off by
default, exposes it only for a rear camera, and uses the same 2.5-second/level
32 defaults. This is bounded illumination, not automatic flash metering, HDR,
or vendor-camera image processing; the front fixed-focus camera must never
start it.

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
| Exposure compensation | Yes | Yes | Yes | Standard `ExposureValue`, -1..+1 EV; r30/current app |
| Variable frame duration | Yes | Yes | Yes | Standard `FrameDurationLimits`; client-selectable to a conservative 15 fps |
| Automatic white balance | Yes | Yes | Yes | Standard `AwbEnable`; r30/r8/r32 round trip live-tested |
| Manual white balance | Yes | Yes | Yes | Standard two-element `ColourGains`; red/blue 0.1–4.0 UI and per-sensor persistence |
| Colour correction matrix | Yes | Yes | Yes | Standard nine-element `ColourCorrectionMatrix`; bounded identity/custom requests live-tested while AWB is manual |
| Continuous autofocus | Yes | Yes | No hardware | Added and live-tested in isolation |
| One-shot autofocus | Yes | Yes | No hardware | Trigger/state sequence tested |
| Tap-to-focus | Yes | Yes | No hardware | Snapshot sensor-region transport live-tested |
| Manual rear focus | Yes | Yes | No hardware | `LensPosition` 0..2 maps to DAC 400..800; live metadata sweep passed |
| Contrast | Yes | Yes | Yes | `0..2` |
| Gamma | Yes | Yes | Yes | `0.1..10` |
| Sensor calibration profile | Yes | Yes | Yes | Stable per-sensor profile for exposure, AWB/gains, optional matrix and tone/detail controls; manual focus is rear-only |
| Saturation | Yes | Yes | Yes | `0..2`; 0 and 2 endpoints tested |
| Sharpness | Yes | Yes | Yes | `0..2`; 0, default 1 and 2 tested |
| Digital zoom | Yes | Yes | Yes | Camerabin 1x..4x preview and capture; synchronized chip stays in the toolbar above the mode selector |
| Full-frame still mode | 2048x1536 | 2048x1536 | 2048x1536 | Snapshot caps selection and live negotiation tested |
| Software HDR | Yes | Yes | Yes | Opt-in three-JPEG exposure fusion in Advanced Snapshot; not sensor WDR or the Android vendor pipeline |
| Hardware flash pulse | Optional | Optional | No | `pmos-camera-flash` helper; writable rear `*:flash` channels required; live LED/capture acceptance pending |
| Manual shutter and analogue gain | Yes | Yes | Yes | Standard `ExposureTime`/`AnalogueGain` controls; lower-layer source/package path live-tested |
| Vendor AWB presets | No | No | No | The open path provides automatic mode and explicit red/blue gains, not proprietary scene presets |
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

The twenty-patch libcamera 0.7.2 series is in
`patches/libcamera/v0.7.2/`. Sensor tuning files are in
`config/libcamera/simple/`. The PipeWire 1.6.8 transport patch and Snapshot
50.0 six-patch application series have their own versioned directories under
`patches/`. The single pmaports integration diff in `packaging/pmaports/` adds
all patches, tuning, checksums, package revision bumps and the pinned Advanced
Snapshot aport. The Android-only Camera3 patches, build helper and provider
configuration are documented in [WAYDROID.md](WAYDROID.md). The Android series
now contains nineteen patches, including the manual-focus bridge and
active-array AF-region correction.

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
pmbootstrap -p "$PWD" build --arch aarch64 advanced-snapshot
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

The current reference build produced `libcamera`/`libcamera-ipa` r31,
`pipewire-spa-libcamera` r8, Snapshot r3, Advanced Snapshot r32 and the SDM845
kernel r10. See `packaging/pmaports/README.md` for hashes and rollback rules.
These commands build packages only; no reboot is implicit.

## Validation

All camera processes were bounded, captures remained private and both rear
lenses were parked at DAC 0 after tests.

### Current r31 runtime entry

- The signed AArch64 `libcamera`/IPA r31 pair is installed and its three
  deployed profile hashes match the source and build output exactly.
- The bounded live validator completed both rear tap/reset transitions and
  10-second stability windows with zero restarts and zero post-reset lens
  requests: main recorded 41 post-reset metrics, secondary 54, and the fixed-
  focus front stream completed 120 frames.
- PipeWire, WirePlumber and pipewire-pulse remained active after the package
  replacement. No reboot, bootloader or kernel change was involved.

This validates profile selection, packaging and stream stability. It does not
replace a controlled chart comparison or prove Android-vendor image parity.

### Historical r28/r24 runtime entry

- Native PipeWire validation passed on the installed r28/r24 stack. Main and
  secondary returned `focused`, completed the scan-free Reset transition and
  recorded 183 and 239 continuous-focus metrics respectively during the
  60-second stability windows; both recorded zero restarts and zero
  post-reset lens requests. The front completed 120 frames and returned the
  expected fixed-focus status.
- Direct manual `LensPosition` requests at 0.0, 1.0 and 2.0 returned success
  on the active main rear node. The Waydroid Camera2 probe confirmed result
  distances `[0.000,2.000]` with delta `2.000` on both rear IDs and correctly
  reported `manualFocusSupported=false` for the front.
- The Waydroid `tap-focus` probe passed all three cameras; both rear IDs
  reported terminal AF states `[3,4]` and non-empty center AF regions, while
  the front remained AF-disabled. These are control/transport checks, not a
  claim of factory lens calibration or Android image-processing parity.
- The installed tone defaults are gamma 2.0/2.1/2.2, contrast 1.10 and
  saturation 1.35 for IMX371/IMX376/IMX519 respectively. A controlled
  flash-lit preview sweep showed the middle manual position produced the
  strongest measured detail in the staged scene; ambient dark captures were
  deliberately not used as optical-quality evidence.

The historical r24 validation below is retained for rollback provenance.

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
- After installing r22, all three nodes accepted combined Exposure,
  Saturation, Contrast and Sharpness updates at -1, +1 and 0 EV, and each
  completed a separate bounded three-frame RGBA capture. The controls were
  reset to sensor defaults after the test.
- A live IMX519 regression sequence measured mean luminance 107.58 at 0 EV,
  76.74 at -1 EV, 84.92 after returning to 0 EV, 124.34 at +1 EV and 116.94
  after the final return to 0 EV. Against the average 0-EV samples, -1 EV was
  0.744x and +1 EV was 1.205x. The changing scene and AGC settling make this a
  directional control test, not photometric calibration.
- Snapshot 50.0-r3 started through its normal application service without a
  panic or assertion and terminated cleanly after the smoke test. The phone
  remained locked, so visible slider, reticle and saved-file acceptance still
  require a later touchscreen check; no lock was bypassed.
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
- The r24 integration patch applied to the pinned pmaports base, and a clean
  pmbootstrap 3.11.1 aarch64 build produced libcamera SHA-256
  `80b3d0e0f55c492783bb95f031d2464dcf3e201e94ce9ea4dbfe7bc1473ef7b9`
  and IPA SHA-256
  `12023c5e4fb52588d531c3d643fa16ba7a992ef4ae3cbd0d6de235d0efcf79b8`.
- The offline r23-to-r24 simulation listed exactly two upgrades and no
  removal. Installation left `/etc/apk/world` byte-identical. All three stable
  camera paths completed bounded native streams. Both rear cameras accepted a
  PipeWire tap, settled, resumed continuous mode without a scan, and then held
  focus for their timed stability windows. The fixed-focus front completed 120
  frames and rejected focus with the expected status 3.
- The full native libcamera test run had 48 passes, one expected failure, 31
  hardware skips and no failures. PipeWire passed 52 of 52 tests. Clean
  aarch64 package builds completed for libcamera r24, PipeWire r7, Snapshot r3
  and Advanced Snapshot r1. All six Advanced Snapshot Aperture unit tests
  passed, including truthful focus-result parsing.
- The regenerated integration patch applied and reverse-checked on a fresh
  detached pmaports `875bddba6538818f2c3c9849e184f40688ad5140` worktree.
  Every resulting file matched the audited staging tree byte-for-byte; its
  SHA-256 is
  `e469b067e84a034708a87a667503dee638774f7b2de394e8af623affb6c48b23`.
- The coherent r7/r1 transaction upgraded exactly the PipeWire SPA, Advanced
  Snapshot and its language package with no removal. Both rear cameras emitted
  a generation-correlated `focused` result, completed 60 seconds after reset
  with zero restarts or lens requests, and the fixed-focus front completed 120
  frames while rejecting focus as unsupported. The packaged app also stayed
  alive through desktop D-Bus activation and terminated cleanly. This is
  non-image runtime acceptance; visual photo/video checks remain separate.

The retained r23 libcamera APKs remain the immediate r24 rollback. The r8 plus
r20/r6/r2 package set remains the complete older baseline. The current phone
validation described above uses kernel r10 with r28/r7/r3 userspace and
Advanced Snapshot r24. Keep the exact r24/r1 or r24/r3 package set as a
rollback before changing the lower layer or application independently.

## Installation boundary

Do not unload camera modules on a running phone. A kernel package replaces
modules under the current release path, so after any approved kernel upgrade
do not open the camera or load modules before the approved reboot. The current
r28/r24 camera generation is userspace-only and does not require a kernel
upgrade or reboot.

To reproduce the completed installation safely:

1. retain exact copies or verified rebuilds of the prior libcamera/IPA and app
   packages;
2. stage patched and rollback APKs in separate offline repositories;
3. put the aarch64 APKs and `APKINDEX.tar.gz` under each repository's
   `aarch64/` directory;
4. pass the repository root—not its `aarch64/` subdirectory—to apk-tools 3,
   run `apk upgrade --simulate`, and require only the intended userspace
   upgrades, with no removal;
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
