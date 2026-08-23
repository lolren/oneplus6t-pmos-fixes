# Front camera

## Root cause

The OnePlus 6T front camera is a Sony IMX371 with a Quad Bayer colour
filter. Its full sensor readout repeats each colour over a physical 2x2
block:

```text
R R G G
R R G G
G G B B
G G B B
```

The current Linux driver exposes that readout as ordinary 2x2 RGGB.
libcamera consequently demosaics the wrong colour pattern. This accounts for
both reported symptoms: the image is nearly monochrome and a regular grid is
visible across it.

The normal preview and video solution is the IMX371 hardware-binned mode. The
sensor combines every same-colour 2x2 block and emits conventional RGGB at
2304x1728. This avoids a proprietary full-resolution remosaic stage, reduces
CSI bandwidth and requires less software-ISP work.

## Related gain defect

The sensor gain equation is:

```text
gain = 1024 / (1024 - register_code)
```

Code 960 is therefore 16x gain. The current kernel limit is 480, which permits
only about 1.88x, and libcamera 0.7.2 has no IMX371 sensor helper. Its simple
IPA reports `Failed to create camera sensor helper for imx371` and otherwise
treats the register code as if it were a linear gain value.

The patch set corrects both sides:

- the kernel gain control extends to code 960; and
- libcamera gains an IMX371 helper with the 1024-based conversion and a
  10-bit black level of `0x40` (`4096` in libcamera's 16-bit scale).

## Included patches

Kernel patches for `sdm845-mainline/linux` tag `sdm845-7.1-rc1-r0` are in
`patches/linux-postmarketos-qcom-sdm845/`:

1. add the exact 2304x1728 2x2-binned mode and 399 MHz link configuration;
2. advertise that link frequency in the shared OnePlus 6/6T device tree; and
3. correct the analogue-gain control range.

The libcamera helper is supplied in two forms:

- `patches/libcamera/v0.7.2/` applies to the version currently packaged by
  postmarketOS; and
- `patches/libcamera/upstream/` applies to current libcamera `master`.

The patches contain no Android camera libraries, vendor tuning blobs, photos,
device identifiers or other proprietary/user data.

## Evidence and offline validation

The failing processed frame was 1920x1080. Its corresponding packed RAW10
frame was advertised as 4656x3496. Splitting a flat part of that raw frame by
`x mod 4` and `y mod 4` showed four stable 2x2 same-colour clusters, not an
ordinary Bayer mosaic.

For a non-invasive proof, the active raw area was grouped into physical 2x2
blocks, producing a 2304x1728 ordinary RGGB mosaic. A conventional edge-aware
demosaic then removed the grid and restored independent colour channels. No
test image is committed because the captures are private.

The binned register table, output size, frame/line timing and 798 Mbps per-lane
rate were cross-checked against the factory 2304x1728 sensor mode. The table in
the kernel patch is byte-for-byte identical to that mode.

## Build and test safety

Do not unload `imx371` on a running OnePlus 6/6T. The tested stock kernel's
remove path emitted a Qualcomm camera-clock warning, and kernel lockdown
rejects an unsigned replacement module. The stock driver was recovered by a
normal sysfs bind retry, but module swapping is not a supported test method.

Use the normal postmarketOS kernel package build. A rebuilt kernel embeds the
same generated signing key that signs its modules. Installation and the first
reboot must be a separately approved operation with the installed stock APK
retained for rollback. None of the camera patches touches the bootloader, A/B
slot metadata, partition table, firmware or UFS boot configuration.

The reproducible pmaports integration patch and exact build commands are in
[`packaging/pmaports/`](../packaging/pmaports/). It updates only the SDM845
kernel and libcamera package recipes; applying it does not install anything.
On the reference build, both packages completed successfully for `aarch64`.
The resulting IMX371 module has matching `7.1.0-rc1-sdm845` vermagic, a PKCS#7
signature from the kernel build key, the compiled gain limit of 960, and a
OnePlus 6T DTB containing both 654 MHz and 399 MHz front-camera link rates.

After booting a patched package, verify in this order:

1. enumerate the front camera and confirm both 2304x1728 and the existing raw
   mode are reported;
2. capture a bounded 1920x1080 preview and confirm libcamera selects
   2304x1728 RGGB input;
3. check that no CSI, DPU, IOMMU or sensor I/O error was added to the kernel
   log;
4. capture a neutral scene and a scene containing red, green and blue objects;
5. confirm the four-pixel grid is absent at 1:1 view;
6. exercise exposure from bright to dim light and confirm gain metadata stays
   between 1x and 16x; and
7. test front-camera still capture, video and repeated open/close cycles.

## Remaining limitation

The 16-megapixel Quad Bayer readout needs a remosaic algorithm before it can be
treated as a conventional colour image. Android uses a vendor remosaic stage.
This project deliberately does not redistribute or load that component.
Normal processed front-camera output should use the hardware-binned
2304x1728 mode; full-resolution raw access can remain available for future
open remosaic work.

Colour-matrix and lens-shading calibration should be evaluated only after the
binned path is live. They can improve accuracy and corner uniformity, but they
cannot fix the original CFA mismatch and must not be guessed from one scene.

## References

- [Sony: Quad Bayer Coding](https://www.sony-semicon.com/en/technology/mobile/quad-bayer-coding.html)
- [SDM845 mainline IMX371 driver at the patched base tag](https://gitlab.com/sdm845-mainline/linux/-/blob/sdm845-7.1-rc1-r0/drivers/media/i2c/imx371.c)
- [libcamera sensor-helper source](https://gitlab.freedesktop.org/camera/libcamera/-/blob/master/src/ipa/libipa/camera_sensor_helper.cpp)
- [LineageOS OnePlus SDM845 proprietary-file inventory](https://github.com/LineageOS/android_device_oneplus_sdm845-common/blob/lineage-22.2/proprietary-files.txt)
