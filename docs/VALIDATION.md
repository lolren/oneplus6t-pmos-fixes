# Validation record

All values below are sanitized. No IMEI, IMSI, ICCID, telephone number, account
credential, SSH key or device-unique serial is recorded.

## Environment

Validated on 23 August 2026:

- device: OnePlus 6T (`oneplus-fajita`), 8 GB / 128 GB;
- distribution: postmarketOS edge;
- kernel: `7.1.0-rc1-sdm845` (currently package r5);
- libcamera: initially `99990.7.2-r2`, currently r3 (upstream 0.7.2);
- Snapshot: `50.0-r1`;
- NetworkManager: 1.56.1;
- ModemManager: 1.25.95; and
- provider database package: `mobile-broadband-provider-info-20251101-r1`.

## Cellular results

The modem registered on LTE at home with packet service attached. The
installer detected operator `23420` and GID1 `0309`, then selected SMARTY's
official `mob.asm.net` APN from the reviewed overlay.

The following checks passed:

- dry-run provider selection with no changes;
- refusal of real-database ambiguity when the GID was deliberately changed;
- first managed-profile activation;
- IPv4 ping bound to `qmapmux0.0`;
- DNS lookup bound to `qmapmux0.0`;
- IPv4 HTTPS bound to `qmapmux0.0`, returning HTTP 200;
- explicit connection down/up with the fallback profile disabled;
- a second installer run replacing its first managed profile transactionally; and
- isolated `--no-activate` installation and rollback, confirming that both the
  test profile and marker were removed while the real SMARTY profile remained
  active.

Local fixtures also cover a newer provider database with two providers sharing
one MCC/MNC and distinct `<gid1>` values. The exact GID selected the correct
Internet APN; a non-matching restricted provider was refused. The parser was
also tested against GNOME provider-database `main`.

The same shell selection suite passed under Alpine BusyBox `ash` on the phone.

Package staging with `make install DESTDIR=... PREFIX=/usr` and static shell
syntax validation of `packaging/APKBUILD` passed. `apkbuild-lint`, pmaports
linting and a clean aarch64 `abuild` remain pending; an isolated Alpine build
attempt stalled while installing `alpine-sdk`, so no APK artifact is claimed.

The carrier did not assign a global IPv6 address, so IPv6 was reported as
skipped rather than failed. The final active Internet APN is `mob.asm.net`; the
separate active `ims` bearer belongs to `81voltd`.

## Time results

`systemd-timesyncd` is enabled and active, `NTPSynchronized=yes`, and
`/var/lib/systemd/timesync/clock` has a current timestamp. The hardware RTC
still reports 1970; no attempt was made to write it.

## Messages results

Chatty `0.8.9-r13` had an active, non-restarting user daemon, no coredump and no
missing runtime library. A controlled GApplication launch exported a window in
about 0.22 seconds. Closing only that window and launching the packaged desktop
entry with `gtk-launch sm.puri.Chatty` exported a new window in about 0.29
seconds. The window remained stable through the observation period.

The compositor simultaneously recorded repeated failed DRM atomic commits, and
the kernel reported DPU encoder errors. Because the display was allowed to
blank naturally during unattended testing, visual foreground presentation was
not initially claimed. The user subsequently confirmed that Chats opens from
the touchscreen with the screen on.

## Camera results

The first signed camera revision, kernel r5 plus libcamera/IPA r3, was installed
and booted earlier with approval. The phone currently runs that baseline. Its
front IMX371 hardware-binned mode restored colour and substantially improved
the original Quad Bayer image. The full-resolution proprietary remosaic path
is still intentionally absent.

Further work was tested without replacing that installed stack. Each candidate
libcamera APK was extracted under the login user's camera-diagnostics
directory; `LD_LIBRARY_PATH`, IPA module path and IPA tuning path selected it
for a bounded `cam` process only. Kernel r8 was built but never installed.
Private PPM/PNG captures and full logs are excluded by `.gitignore`.

### Sensor and actuator findings

- stable IDs enumerate IMX519 main rear, IMX376 secondary rear and fixed-focus
  IMX371 front;
- both rear LC898217XC controls report DAC range `0..2047`;
- controlled focus sweeps put the useful range near `400..800` for the test
  scene; and
- both actuators were parked at 0 after every completed test.

Kernel and libcamera gain fixes map all three Sony register codes with
`1024 / (1024 - code)`. IMX371 and IMX376 kernel controls expose code 960, or
16x, instead of code 480, approximately 1.88x.

### Autofocus

The final contrast AF uses a central two-dimensional Sobel statistic, coarse
and fine scans, a 10% near-peak plateau centre and continuous-restart
hysteresis.

- Three repeated main-camera scans settled near the same plateau.
- Final continuous tests selected position 600 on both rear cameras and
  reached `AfStateFocused`.
- One-shot `AfModeAuto` plus `AfTriggerStart` reported 240 captured frames as
  `Scanning` and the final 60 as `Focused`.
- After an external forced defocus to 400, continuous mode detected sustained
  contrast loss, restarted exactly once and returned to its prior plateau
  without hunting.
- The front camera correctly exposes no AF controls.

### Grid, crop and frame rate

An isolated CPU/GPU comparison showed that the regular grid was introduced by
the old single-pass EGL demosaic-and-nearest-scale path. CPU demosaic removed
the grid but cropped most of the view. A two-pass EGL prototype first rendered
black because temporary texture-coordinate storage outlived its stack frame;
that candidate was rejected and never installed.

The corrected path demosaics to persistent full-resolution RGB, generates a
mipmapped low-pass pyramid, then center-crops and scales RGB. It retained the
full field of view, removed the regular grid and sustained approximately 30 fps
for a 2304x1728 input rendered at 800x600. Statistics were moved to the exact
displayed crop, and autofocus passed again afterward.

The main IMX519 low-resolution modes were traced independently:

- 800x600 selected 1280x720 at a 120 fps default and capped exposure near
  4.2 ms;
- 1280-class output selected 1920x1080 at a 60 fps default; and
- 1600x1200 selected 2328x1748 at about 30 fps and allowed much longer
  exposure.

Kernel r8 keeps the 120/60 fps minima but changes the first two defaults to
30 fps. The existing VBLANK implementation calculates and applies the longer
frame length; no sensor register table is removed.

### Controls and final builds

Identity CCM tuning exposes saturation on all three sensors. Saturation 0
produced measured average chroma 0; saturation 2 increased average chroma from
approximately 6.4 to 10.1 in the controlled scene. Contrast and gamma remain
available. HDR was not exposed because the simple ISP has no valid
multi-exposure merge or tone-map stage.

The final integration diff applies cleanly to pmaports
`073ff887b0e18c4c80bd94098fda035e0e20d28b`. Clean aarch64 package builds
completed for:

- kernel r8, SHA-256
  `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e`;
- libcamera r18, SHA-256
  `360e1c718650907065f8322d1d01a57b27591b7ca827b3a0e8821c7082d93a63`;
  and
- libcamera IPA r18, SHA-256
  `4f1748ff710b67b6ef7d8f4e32c1e5f33dc84fa9c1d508192e4a88dc12285083`.

The final r18 runtime enumerated all three cameras, exposed autofocus controls
on both rear modules and none on the fixed-focus front module, and completed a
bounded 30-frame front capture through the filtered EGL path at approximately
30 fps. It was extracted under the login user's home directory and was not
installed into a system package path.

The r8 IMX519 module has matching `7.1.0-rc1-sdm845` vermagic and a PKCS#7
SHA-512 build-key signature. The final kernel package was checked to ensure the
discarded actuator diagnostic experiment is absent. No final package was
installed or copied into a system package path.

## Remaining validation

A normal reboot test has not yet been performed for this repository revision.
NetworkManager profile persistence and autoconnect were verified with a manual
down/up cycle; boot-time reconnection must be recorded separately after an
explicitly approved reboot.

The final r8/r18 system transaction and reboot remain pending fresh approval.
After that, record application-level preview, still/video, flash expectations,
screen-off/on, repeated-open, suspend/resume and rollback tests. Android-level
HDR, denoise, calibrated CCM/lens shading and computational fusion remain
unimplemented and are not represented as completed work.
