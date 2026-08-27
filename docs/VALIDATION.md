# Validation record

All values below are sanitized. No IMEI, IMSI, ICCID, telephone number, account
credential, SSH key or device-unique serial is recorded.

## 2026-08-26 daily-use setup host gate

The new `configure-daily-use` wrapper sequences the existing cellular,
network-time and microphone-route helpers. It defaults to read-only preview,
requires `--apply` before changing state, runs privileged helpers through
`sudo` from the graphical user's session and enables only the user's audio
unit. It does not install packages, touch Waydroid or reboot.

The focused wrapper test and the complete pMOS suite passed on 2026-08-26:

```text
daily-use setup tests passed
make test: pass
```

The staged installation also verified the executable helper, `/usr/sbin`
symlink and installed `DAILY-USE.md`. Live apply and bearer/clock/modem-call
acceptance remain gated by the unavailable OnePlus userspace transport; this
host result does not claim that the phone has been changed.

## Environment

Validated on 23-24 August 2026:

- device: OnePlus 6T (`oneplus-fajita`), 8 GB / 128 GB;
- distribution: postmarketOS edge;
- kernel: `7.1.0-rc1-sdm845` (currently package r8);
- libcamera: initially `99990.7.2-r2`, currently r24 (upstream 0.7.2);
- PipeWire libcamera SPA plugin: `1.6.8-r6`;
- Snapshot: `50.0-r3`;
- NetworkManager: 1.56.1;
- ModemManager: 1.25.95; and
- provider database package: `mobile-broadband-provider-info-20251101-r1`.
- Waydroid: 1.6.3, Android 13 ARMv7 mainline image.

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
and booted earlier with approval. Kernel r8 plus libcamera/IPA r18 was
subsequently installed and booted with approval. The r19 userspace revision
then became the rollback baseline for the current r20 work. The front IMX371
hardware-binned mode restores colour, while the full-resolution proprietary
remosaic path remains intentionally absent.

The r19 userspace work was first tested without replacing that installed
stack. Its libcamera APKs were extracted under the login user's
camera-diagnostics directory; `LD_LIBRARY_PATH`, IPA module path and IPA tuning
path selected it for bounded `cam` processes only. After those tests, the same
r19 `libcamera` and `libcamera-ipa` builds replaced r18 in an offline
two-package transaction. Private PPM/PNG captures and full logs are excluded by
`.gitignore`.

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

### Colour and automatic exposure

The r19 software ISP records separate linear red, green and blue histograms.
AGC uses the current white-balance gains to constrain the configured channel
quantile after white balance, where the earlier luminance-only statistic could
miss coloured clipping. All three OnePlus tunings use quantile 0.98 and target
0.95. Sensor-specific gamma, contrast and saturation defaults remain
application-overridable.

For the same staged scenes in separate 800x600 bounded runs:

| Camera | Chroma before | Chroma r19 | Near-clip before | Near-clip r19 |
| --- | ---: | ---: | ---: | ---: |
| Front IMX371 | 10.1 | 13.3 | 9.20% | 0.03% |
| Main IMX519 | 23.4 | 34.1 | 0.12% | 0.01% |
| Secondary IMX376 | 24.5 | 27.1 | 2.15% | 0.13% |

The values come from `tests/camera/ppm-metrics.py`; they are regression
measurements, not colour-chart calibration. The main-camera physical light
step reduced gain from 16.0 to 4.697 and returned to 16.0. The secondary
reduced exposure from 66.4 ms at gain 2.51 to 34.1 ms at gain 1.0 and recovered
to its initial exposure product. Both LED channels read back 0 afterward and
both actuators read back DAC 0.

The rear flash cannot illuminate the front scene, so its sensor path received
a separate isolated threshold test. A target of 0.50 converged to measured
highlight 0.4998 at 23.7 ms and gain 1.0. Restoring production tuning raised
exposure smoothly to 27.7 ms and approximately gain 1.30.

Legacy tuning without either new highlight key preserved gamma 2.2, contrast
1, saturation 1 and disabled highlight protection. A missing key from the pair
and an out-of-range adjustment default were both rejected. The native build
completed 48 tests, one expected failure and 30 hardware skips with no failure.

### r19 controls and builds

Identity CCM tuning exposes saturation on all three sensors. Saturation 0
produced measured average chroma 0; saturation 2 increased average chroma from
approximately 6.4 to 10.1 in the controlled scene. Contrast and gamma remain
available. HDR was not exposed because the simple ISP has no valid
multi-exposure merge or tone-map stage.

The r19 integration diff applied cleanly to pmaports
`073ff887b0e18c4c80bd94098fda035e0e20d28b`. Clean aarch64 package builds
completed for:

- kernel r8, SHA-256
  `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e`;
- libcamera r19, SHA-256
  `073eb1f4b6d26d5573847724b13d2fe9ce79d4b578fa0a4e7097b1a108c79c91`;
  and
- libcamera IPA r19, SHA-256
  `fb9b5040714462c06750a28916c3ced706cd254ac502974c446b48a1325b2a0b`.

The isolated r19 runtime enumerated all three cameras, exposed autofocus
controls on both rear modules and none on the fixed-focus front module, and
completed a bounded capture on every sensor through the filtered EGL path.

The installation simulation listed exactly the r18-to-r19 `libcamera-ipa` and
`libcamera` upgrades and no removal. The same offline command was then run
without `--simulate`; it upgraded only those packages. The installed stack
enumerated all three production tuning files. A front capture completed 180
frames at approximately 29 fps with its r19 adjustment defaults, and the main
and secondary physical light-step tests again reduced exposure under added
light and recovered afterward. Two further sequential open/capture/close rounds
passed on every camera. Both LED channels and both rear actuators read back 0,
and no camera process remained after cleanup.

The r8 IMX519 module has matching `7.1.0-rc1-sdm845` vermagic and a PKCS#7
SHA-512 build-key signature. The kernel package was checked to ensure the
discarded actuator diagnostic experiment is absent. Kernel r8 remains
installed; the exact userspace r19 set is now the rollback baseline for r20.

### r20 detail, tap-to-focus and Snapshot

The current source additions were audited and built independently against
libcamera v0.7.2, PipeWire 1.6.8 and Snapshot 50.0. Each exported patch series
was reapplied from its exact clean upstream tag with
`git am --whitespace=error-all`, and the resulting trees matched the audited
source commits byte for byte. Native CPU and EGL libcamera builds passed 48
tests, one expected failure and 30 hardware skips with no failure. PipeWire
passed all 52 tests. Exact aarch64 package builds completed for libcamera r20,
PipeWire r6 and Snapshot r2.

The current pmaports integration patch applies to
`875bddba6538818f2c3c9849e184f40688ad5140`. Its 36 resulting files matched the
audited staged tree byte for byte. Reference package hashes are:

| Package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r20.apk` | `63f72a082088085c04ec42975ffadb5aa386d66a024c54394a3b5180fc628764` |
| `libcamera-ipa-99990.7.2-r20.apk` | `4c61f6b27f6b9f843b32bb292d57056cf9bafe321dfdb7648acbf28a47f649a8` |
| `pipewire-spa-libcamera-1.6.8-r6.apk` | `658658c3b9df142a6462e3a73457b44a378d6820dba0c6b05a14d18f865635d4` |
| `snapshot-50.0-r2.apk` | `f096f4a566fe5801fce8b784759f83222eeeba15a36829bf10f129ab764d4cc6` |
| `snapshot-lang-50.0-r2.apk` | `a86902e92caee59ca42113ccda42b08813e9975185012389f17826f114dbdaec` |

The offline simulation showed exactly the five expected r19/r5/r1 to
r20/r6/r2 upgrades and no removal. Four packages upgraded together; the
noarch language package had been placed outside the indexed architecture
directory and therefore failed that first transaction. Installing that one
verified APK completed the upgrade. The exact version pin added by direct
`apk add` was then removed from `/etc/apk/world`; its SHA-256 returned to the
pre-install value
`9460e1c7012bb4027b2c8c7e626afc2569cb4ec2998e9096a15207237c9b09a2`.
All five target versions remained installed. The later apk-tools 3 layout test
clarified the clean reproduction: include the noarch APK while generating the
native index, store the APK itself under `noarch/`, and pass the repository
root. See the r21/r22 record below.

Installed camera enumeration found the three stable sensor IDs and production
tuning files. Main and secondary advertised `Sharpness 0..2`, saturation,
gamma, contrast, `AfMode`, `AfTrigger`, `AfMetering` and `AfWindows`; the fixed
front advertised the four image controls and no autofocus. Bounded captures
completed for 300 main frames, 300 secondary frames and 180 front frames. Both
rear runs reached `Focused` and the lenses were parked afterward.

In a separately staged front scene, the sharpness endpoints measured:

| Sharpness | Edge signal | Laplacian signal |
| ---: | ---: | ---: |
| 0 | 2.34 | 3.17 |
| 1, production default | 2.72 | 4.35 |
| 2 | 2.99 | 5.52 |

Exposure changed somewhat between runs, so these values establish control
ordering rather than an absolute image-quality score. Private visual review
kept default 1: it improves detail without forcing the visibly stronger
maximum. The installed final frames measured the following scene-dependent
regression signals; the scenes differed from earlier revisions and therefore
must not be used for a before/after quality claim:

| Camera | Luma | Chroma | Edge | Laplacian |
| --- | ---: | ---: | ---: | ---: |
| Front | 141.1 | 13.5 | 2.72 | 4.35 |
| Main | 139.7 | 50.2 | 2.67 | 2.41 |
| Secondary | 127.9 | 28.5 | 3.70 | 4.77 |

For live tap-focus transport, a negotiated 640x480 main PipeWire stream
published effective crop `1368,1042,1920,1440`, maximum crop
`1048,1042,2560,1440` and libcamera orientation 6. The exact installed Snapshot
helper accepted focus and reset commands on both rear nodes. The main physical
lens moved from parked DAC 0 to DAC 400. The front node returned the expected
`camera does not support tap-to-focus` result. Main, secondary and front also
each negotiated three bounded 2048x1536 frames. Source-level orientation tests
covered all eight libcamera orientations.

The phone was locked during unattended validation, so Snapshot correctly did
not keep its preview active. An actual touchscreen tap, focus marker and saved
2048x1536 file remain user-interface acceptance tests after unlock; the lower
layer control path and full-frame caps are validated. No lock was bypassed.

PipeWire and WirePlumber remained active with zero restarts after validation.
No camera process remained, both flash channels read 0 and both dynamically
resolved rear actuators read DAC 0. Visual review found a clear improvement
over r19, but calibrated CCM/LSC, temporal denoise, HDR and proprietary
multi-frame processing remain absent, so Android image parity is not claimed.

### r21/r22 exposure and Snapshot r3 controls

The next userspace revision added standard ±1 EV compensation and Snapshot's
visible focus reticle plus Exposure, Colour, Contrast, Detail, Zoom and Reset
controls. The source patches applied cleanly to exact libcamera 0.7.2 and
Snapshot 50.0 parents. Snapshot r3 and the initial libcamera r21 candidate both
completed clean aarch64 package builds.

Starting from r20/r6/r2, the offline solver listed only two libcamera upgrades
and two Snapshot upgrades. apk-tools 3 then exposed an important repository
layout detail: the native index was read from `aarch64/`, but the package
declared `A:noarch` was fetched from `noarch/`. Because that file had only been
placed beside the native index, the first live transaction completed the three
aarch64 upgrades and stopped at the language package. The verified noarch APK
was installed directly, and the exact pin introduced by that command was then
removed without removing the installed language data. `/etc/apk/world`
returned to its pre-transaction SHA-256
`71247b09e8b6edb0d5540c45499ea76d98d27666f9750f6532c6e201a906547b`.
The documented reproduction now stages `snapshot-lang` under `noarch/`, indexes
both directories and passes the repository root. A separate apk-tools 3.0.7
fetch test resolved that path and produced a byte-identical file.

A live r21 luminance sequence found that the fixed highlight guard cancelled
most positive compensation: -1 EV measured 0.904x baseline, while +1 EV was
only 1.010x. r21 was therefore superseded rather than declared complete. r22
moves the highlight ceiling and hysteresis by the same power-of-two EV scale as
the mean target; zero EV remains identical to the prior highlight policy. The
Android HAL build also compiled with the corrected algorithm.

Reference final package hashes are:

| Package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r22.apk` | `0900e38b7945778e1e0c9219db9ad5a1fc31bcc7a9a154aa4dd7830fc3519644` |
| `libcamera-ipa-99990.7.2-r22.apk` | `6e56cbd696d8575d19a9aedf54093421718470ee67c1597dcb261d4dce41c9e9` |
| `snapshot-50.0-r3.apk` | `5a59c32a3d3ef451bc85b0f19cb8fce617aaa4c6baba83e3595ddb9892a324e7` |
| `snapshot-lang-50.0-r3.apk` | `8eb9fd567ce10c91afb00a98e10b0056d7adbd7683ab0514c217806512b0b108` |

The r21-to-r22 simulation and installation listed exactly `libcamera-ipa` and
`libcamera`, with no removal and zero size change. The world-file hash remained
the value above. Only PipeWire and WirePlumber were restarted; no kernel module
was unloaded and no reboot occurred. All three sensors were rediscovered.

Each sensor accepted combined Exposure, Saturation, Contrast and Sharpness
updates at -1, +1 and 0 EV, then completed a bounded three-frame RGBA capture.
The IMX519 live sequence measured:

| Requested EV | Mean luminance |
| ---: | ---: |
| 0, initial | 107.58 |
| -1 | 76.74 |
| 0, after -1 | 84.92 |
| +1 | 124.34 |
| 0, final | 116.94 |

Relative to the average of the three 0-EV samples, -1 EV measured 0.744x and
+1 EV measured 1.205x. The values are a directional live-control regression
test, not photometric calibration; the scene and AGC settling changed between
samples. The helper restored 0 EV afterward.

Snapshot 50.0-r3 launched through its normal application service without a
panic, assertion or template error and terminated cleanly after the smoke test.
The phone remained locked, so the visible reticle, sliders, zoom and a saved
full-resolution image remain touchscreen acceptance tests. No lock was
bypassed. The regenerated pmaports integration patch applies to
`875bddba6538818f2c3c9849e184f40688ad5140`; all 38 resulting files matched the
audited staged tree, and the patch SHA-256 is
`f063d147676f957580f425c430cc39407e60a4ec0edfa6dfb29d2f4788d5140a`.

### r23 frame duration and Waydroid Camera3

The generic r23 patch carries VBLANK through delayed controls, advertises
`FrameDurationLimits` only for supporting sensors, applies a requested frame
length before expanding exposure and reports active frame duration. The mode
default remains unchanged until a client requests a range. Native CPU source
tests completed with 48 passes, one expected failure, 30 hardware skips and no
failure.

The regenerated pmaports integration patch applies to
`875bddba6538818f2c3c9849e184f40688ad5140`, adds fifteen libcamera patches and
has SHA-256
`1e4f4fa1d1445200d43e6e7ee63ea2ed200b6a0cd64ac2c44be970493955475a`.
A clean pmbootstrap 3.11.1 aarch64 build completed with:

| Package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r23.apk` | `45f6bd97df378aa8820f4651675f1b11b5d55f1294fe8116d6f01265c832687d` |
| `libcamera-ipa-99990.7.2-r23.apk` | `63dcf5ef5b1fdc29652b5c2e5e3e729681719c42f06c1183e010e71d94067bf2` |

The phone-side offline simulation listed exactly the r22-to-r23 IPA and
libcamera upgrades and no removal. The same transaction installed both;
`/etc/apk/world` remained SHA-256
`af487ff52d686ad8fe74e9c15f1e4d9bd5d2b5a2234a1a2aa58d9847c3903075`
before and after. Exact r22 rollback APK hashes were rechecked first. PipeWire
was restarted without a phone reboot. All three stable native camera paths
enumerated and completed separate bounded 30-frame 800x600 captures. In the
main rear control context, `FrameDurationLimits` enumerated as
`[52752..66667]` microseconds alongside EV and autofocus controls.

The Android-only patch was cross-compiled for ARMv7 API 33 with NDK
29.0.14206865. It added explicit minigbm plane layouts, software NV12 output,
Camera2 exposure/frame metadata, variable FPS translation and rear AF
modes/triggers/regions. The checked-in build helper was then rerun from empty
build and stage directories; all 195 compile steps, installation, HAL discovery
copy, tuning installation and final hash checks completed. The final installed
Waydroid runtime hashes were:

| Runtime file | SHA-256 |
| --- | --- |
| `camera.libcamera.so` | `c0def226bb98703882d747d048678e21f8934dad3678dbc4b0674c9630dbe6ef` |
| `libcamera.so` | `beb6b2a226ce4395f3f6627865183fef46a6df60bd287c203720bf6e6d2645d4` |
| `libcamera-base.so` | `ee7afde21eeea3cd1c0a8f8b87f68abbaca1b29b48eb3452d89b69223a25e8b9` |
| `ipa_soft_simple.so` | `266877375bb694d3f591280b2abbe0b3df114110a3d78ca3074a7aab06b7ad22` |
| `ipa_soft_simple.so.sign` | `879f8183a0b1f58011f0bcc0da883c76fbd853809d252837c6f629c79e90c9b7` |

A dated overlay backup was hash-verified before replacement. After a Waydroid
restart, Android reported three closed, available devices. The final unattended
Camera2 probe completed `PROBE_DONE valid=3 total=3`. Every camera returned
valid YUV, JPEG and implementation-defined frames plus -1/0/+1 EV metadata.
Both rear cameras reported AF states `[3, 4]`; the fixed-focus front reported
`[0]`. In the final scene, all three showed measured pixel movement rather than
requiring the sensor-limit exception. The result file SHA-256 was
`deb7756daa3fd0c1f21a8a703a4c264a9e9417353888bd6f127fd5269cfd64c2`.
Private JPEGs were not committed.

The separately installed provider fragment was then tested through another
Waydroid container/session restart. With the reference host video GID rendered
as 27, its SHA-256 was
`f7a52425dcde9996b4119ab1115e9f6df0550cf0890f8e9f9a3987848e4ed733`.
Android completed boot, the provider process retained supplementary groups
`27 1004 1006 1026`, and `dumpsys media.camera` again reported three closed,
available devices. No duplicate-service or failed-override error was present.

Temporary per-frame exposure debug logging was removed after the probe. A
production restart retained three-camera enumeration. The Android framework
did log a recoverable JPEG blob-footer warning and occasional close/flush
timeout during the stress run; every JPEG decoded and each following camera
opened. These warnings remain tracked for broader application compatibility
testing.

### r24 autofocus transition stability

The r24 generic commit
`fd0d181356dffecf4256d0c1876f75dfa68b410f` replaces full-range repeat scans
with a progressive search centred on the last successful position. It adds
configurable settle frames, a bounded fine range, faster explicit tap
measurements, final-position validation, an adaptive continuous-focus
reference and a scan-free return from tap-focus to continuous mode. The
Android Camera3 commit
`aac57582a4af4b9cfae4f741fe2dc14e0c270887` was rebased on that generic
commit, so the native and Waydroid stacks share one AF implementation instead
of duplicating it.

A clean native x86 build passed. The full native test run completed with 48
passes, one expected failure, 31 hardware skips and no failure. A clean Android
ARMv7/API-33 cross-build also passed. Reapplying the sixteen generic patches to
libcamera v0.7.2 and then the Android-only patch succeeded without rejects.
The regenerated pmaports integration diff applies to
`875bddba6538818f2c3c9849e184f40688ad5140`, has SHA-256
`68a419b8f01a90f9b7816eb10a4fe1767f9b75d635be950d1a1b392d77aadb6e`,
and produced these clean pmbootstrap 3.11.1 aarch64 packages:

| Package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r24.apk` | `80b3d0e0f55c492783bb95f031d2464dcf3e201e94ce9ea4dbfe7bc1473ef7b9` |
| `libcamera-ipa-99990.7.2-r24.apk` | `12023c5e4fb52588d531c3d643fa16ba7a992ef4ae3cbd0d6de235d0efcf79b8` |

Exact r23 APKs were copied into a separate rollback repository and verified
before installation. The offline simulation listed exactly the r23-to-r24
`libcamera-ipa` and `libcamera` upgrades with no removal. PipeWire and
WirePlumber were stopped for the transaction; both returned active afterward.
`/etc/apk/world` remained byte-identical at SHA-256
`960e4755fdf654d63e069c567063943d5a4609dda53c27289dd920f1bdb8a842`.
No kernel, partition, boot slot, module or firmware changed, and the phone was
not rebooted.

Installed native tests used dynamically discovered PipeWire serials. Main
tap-focus moved from DAC 500 through a bounded local search and settled at 650.
Reset logged `Resuming continuous autofocus at lens position 650 without a
scan`, initialized a new whole-frame reference and issued zero lens-position
requests. Secondary tap-focus settled at DAC 430; its Reset preserved 430 and
also issued zero lens requests. Timed stability evidence was:

| Camera | Window | Continuous measurements | AF restarts | Lens requests after stable transition |
| --- | ---: | ---: | ---: | ---: |
| Main IMX519 | 70 s | 177 | 0 | 0 after initial settle |
| Secondary IMX376 | 95 s | 220 after Reset | 0 | 0 after Reset |

The fixed-focus front completed a bounded 120-frame 640x480 RGBA stream. The
installed helper returned status 3 and `camera does not support tap-to-focus`,
as required. Full per-frame logging was replaced by a selective AF trace for
the timed runs; all `LIBCAMERA_*` user-service environment variables were then
unset and PipeWire/WirePlumber restarted in their normal production state.
The checked-in unattended runner was then copied verbatim to the phone and
passed a separate smoke run: 41 main and 54 secondary post-reset measurements,
zero restarts, zero lens requests, and 120 fixed-focus front frames. Its exit
trap restored active services and left no libcamera logging environment or
GStreamer process behind.

The coherent r24 Waydroid overlay was installed only after backing up all
thirteen replaced targets with a presence manifest and SHA-256 list. Reference
runtime hashes are:

| Runtime file | SHA-256 |
| --- | --- |
| `camera.libcamera.so` | `650b18b57db4fbd46441b6cfb443b8275c51c8cfc4c910eacb990407a48b42b9` |
| `libcamera.so` | `6be47c42f61bea0e2b33439cbc290ab1544ccfb1e2dbd2f331b4031f4cde5002` |
| `libcamera-base.so` | `ab80f590a78ea6d830e7ef34fe642850c2304d2da342537e7d8807e7947b7fb0` |
| `ipa_soft_simple.so` | `aa3fcebbf124643a4a0c281c7206f6544249f2415bf468d2aa94a64f82e7b24a` |
| `ipa_soft_simple.so.sign` | `38f32fc98445b32f7f61e1daf16fc211aa11faf6d7e8a17369c52fd9d57ce3df` |

Android booted, the provider reported running and `dumpsys media.camera`
reported three devices. The unattended probe ended with
`PROBE_DONE valid=3 total=3`; rear IDs 0 and 2 returned AF states `[3, 4]` and
real metering regions, front ID 1 returned fixed-focus state `[0]`, and all
three passed YUV, private preview, JPEG, EV and sensor-timing checks. The
sanitized result SHA-256 is
`425a0525ed08c039cba6831b0ec9c6566bec0ebbb1d7b03267b16f71feac2483`.
Generated JPEGs remain private. The Waydroid Android session was returned to
its prior stopped state; its continuously running container service was not
changed. The complete r23 overlay backup remains available for rollback.

## r7/r1 truthful autofocus package and device acceptance

The PipeWire transport was extended without changing libcamera or the kernel.
Its three read-only node properties are
`api.libcamera.af-trigger-generation`,
`api.libcamera.af-state-trigger-generation` and
`api.libcamera.af-state`. The accepted trigger generation is attached to the
queued request, then retained while real request metadata moves through
`Scanning` to `Focused` or `Failed`. This prevents a stale continuous-focus
result from being attributed to a new tap. Fixed-focus cameras publish no
autofocus result.

The final PipeWire mail patch has SHA-512
`698969b493c84f19c28d4f071ec08fce153ad849008fbf181eb2b055921e9b5081f3211002ed21abf5d1647f26dad975ae4ed2a790c798b938c90ab68f5fedd6`.
It reapplied to the PipeWire 1.6.8 source, compiled as AArch64 and passed all
52 PipeWire tests. The signed package is:

| Package | SHA-256 |
| --- | --- |
| `pipewire-spa-libcamera-1.6.8-r7.apk` | `c6e2f3dc9f27b89dc2ebef448e4242bfa3f40ae2606c146b291e5caa85e612d1` |

The extracted plugin is a stripped AArch64 ELF and contains all three focus
properties plus the previously validated crop and orientation properties.

Advanced Snapshot source commit
`f163794d0bd4b796b4f8555c9af1a1e51f42ebf7` waits for a terminal state with a
newly accepted generation. It prints only `focused` or `failed` for truthful
optical outcomes; transport failures remain nonzero. The UI is amber while
waiting, green only for `focused` and red for `failed` or infrastructure error.
The immutable GitHub archive SHA-512 is
`5d1c8197cbe368e6e88313d6fd5e997e5a3cf5aeb442e490ae4be6492c75d0f2721b007e6400c072ac6361445f82fbb216bc258e8dbab19c3c62980d92c0b83d`.

The exact published-source aport passed all six Aperture library tests and its
complete APK validator, including signature, AArch64 ELF, metadata, namespace
and zero ownership overlap with Snapshot:

| Package | SHA-256 |
| --- | --- |
| `advanced-snapshot-0.1.0-r1.apk` | `1e19e6d3bfa990d9ae4440fcc0364383e7cfc36de835689d2a2d5d1748368795` |
| `advanced-snapshot-lang-0.1.0-r1.apk` | `7329bc3133cacd288e1f95e9cb93e69f71acc986b0bf1a875e8e4cd0469a47c8` |

The regenerated pmaports integration patch contains the r7 transport and r1
app aport. It applied and reverse-checked on a fresh detached pmaports
`875bddba6538818f2c3c9849e184f40688ad5140` worktree, and every resulting file
matched the audited staging tree byte-for-byte. Its SHA-256 is
`e469b067e84a034708a87a667503dee638774f7b2de394e8af623affb6c48b23`.

The candidate and rollback repositories were copied to
`/home/user/camera-focus-state-r7-r1-20260825`. All six APK signatures and
hashes were verified before installation. apk-tools 3 retained identity
constraints because both r0 app packages had originally been installed from
local files, so a package-name-only upgrade proposed only PipeWire r7 and was
rejected. The accepted command supplied both r1 app file paths explicitly and
used the candidate repository to resolve their PipeWire dependency. Its
simulation proposed exactly these upgrades and no removal:

```text
pipewire-spa-libcamera  1.6.8-r6 -> 1.6.8-r7
advanced-snapshot       0.1.0-r0 -> 0.1.0-r1
advanced-snapshot-lang  0.1.0-r0 -> 0.1.0-r1
```

The simulation output SHA-256 is
`50b587d9ccf0bc01a957b8c12ff0024d9b3a9c0819ce4e21d2fc2e5bfc817369`.
The real transaction performed the same three upgrades; its output SHA-256 is
`bc1c20a23af1542bb1221af3bbc053e2da71bd399212c3080958e578a7fda269`.
The installed package manifest SHA-256 is
`8ae365661b1e91e7f2f49a9ae3fb7ebeb679f1ddd8fb459803314ba2ba283a63`.

`/etc/apk/world` changed from SHA-256
`e91dd5dc4a85594da5e28d11c014f6fefaf3b16adc6329f7e1000685de84b32e`
to
`d032cb41e42bda904382159b10198e5c2dd9b73cda58d3f0060993756388e276`.
Its diff contained exactly two identity-line replacements: Advanced Snapshot
and its language package moved from the r0 local identities to the r1 local
identities. PipeWire stayed dependency-owned and no unrelated world entry
changed.

The final central-target all-sensor run returned:

```text
main|serial=59|tap_result=focused|post_reset_metrics=183|restarts=0|lens_requests=0
secondary|serial=63|tap_result=focused|post_reset_metrics=239|restarts=0|lens_requests=0
front|serial=61|frames=120|focus_status=unsupported
RESULT|pass|rear_stability_seconds=60
```

The summary SHA-256 is
`e5663d4a894169c097396f7f825199d4bcd211efa398fbb2c274e3fd76acb98c`.
Each rear result file contained only `focused` and has SHA-256
`6c6a45ac86c5a830cda6b4f9552c0d6e782ca4b0ceff9ce261296168bb67699e`.
The front helper truthfully reported that the camera does not support
tap-to-focus; its log SHA-256 is
`fcad6f02190e3fb1d5af2c671becbdcbdfed290aa54d079462dd182166a8bad4`.
An earlier off-centre low-detail target returned `failed`; a centre target then
returned `focused`. This is a useful negative result: the helper reports the
optical terminal state instead of turning control acceptance into success.

The desktop portal had lost its PipeWire connection during the controlled
service stop. Restarting it restored a live Camera interface with
`IsCameraPresent=true` and zero failed user units. The installed r1 app then
launched through `io.github.lolren.AdvancedSnapshot`, reported the independent
version and datadir, stayed alive and terminated cleanly in one second. Its
stdout/stderr were empty and runtime evidence SHA-256 is
`c72f813b583e15bf70616d0f9369727fec91e95332fad1101a78210abb5129ae`.
The unattended phone was not used for visual preview, saved-photo or video
acceptance, so those remain open.

Live rollback was intentionally not performed. The isolated rollback
simulation proposed exactly the three r7/r1-to-r6/r0 downgrades and has
SHA-256
`80ed193f2cda1948189513281e51df615b7ab19a62efa9bd8d71b90fb39fbad9`.
A copied apk database then performed the same local-file downgrade with package
scripts disabled. This temporarily added a PipeWire identity line; modeled
`apk del pipewire-spa-libcamera` removed only that world constraint because the
installed Phosh base, Snapshot and Advanced Snapshot retain the plugin. r6/r0
remained installed and the modeled world hash returned byte-for-byte to
`e91dd5dc4a85594da5e28d11c014f6fefaf3b16adc6329f7e1000685de84b32e`.

After cleanup PipeWire, WirePlumber and the desktop portal were active, no
camera client or autofocus environment remained, and no user unit was failed.
The Waydroid container service has been continuously active since before this
transaction while its Android session remains stopped; no Waydroid state was
changed by the native camera update.

The first acceptance run also exposed a service-lifecycle issue in the test
runner: stopping PipeWire while the main portal and its wlroots backend remained
connected caused transient portal failures. The runner and generation manager
now stop both portal units before every PipeWire cycle and restore both
afterward. A hardware regression then repeated all three sensor checks with
10-second rear stability windows:

```text
main|serial=61|tap_result=focused|post_reset_metrics=41|restarts=0|lens_requests=0
secondary|serial=65|tap_result=focused|post_reset_metrics=54|restarts=0|lens_requests=0
front|serial=63|frames=120|focus_status=unsupported
RESULT|pass|rear_stability_seconds=10
```

The summary SHA-256 is
`aa5d5dedf5834e90ac15bd121a3711b4a7c004df0b5f41a59f155e6013fb9260`.
The bounded portal journal has SHA-256
`9447840432b47360053b37dd960f988994808428223dcd2a25127773a595b201`
and contains only orderly stop/start events: no fatal error, failed result or
coredump. PipeWire, WirePlumber and both portal units ended active; failed user
units, stale camera processes and `LIBCAMERA_LOG_*` environment entries were
all zero. `/etc/apk/world` remained at the accepted r7/r1 hash.

## r7/r2 synchronized-zoom package gate

- Date: 2026-08-25
- Advanced Snapshot feature commit:
  `7be55d5ccce9023acec8a88219a3333ca397e0e3`
- Packaging commit: `3e89329`
- Build target: postmarketOS edge, AArch64, strict isolated pmbootstrap root
- Release build: passed in 16 minutes 19 seconds
- Test-profile build: passed in 1 minute 11 seconds
- Application tests: 4 passed, 0 failed
- Aperture tests: 6 passed, 0 failed

The pinned Git archive SHA-512 is
`c271272431ab4348187418b09a70d9554789aa0a9807716b136164ff024e63c329bf8ad3f3403e7646e8f73e167069bb09e23314501eac5af53bf5a30b231511`.
The updated all-stack pmaports patch SHA-256 is
`a55eb222e38ccd4abc25d0366e8fcc0526ee0d4c73e4103e39ab149fed199f71`;
it passed `git apply --check`, applied cleanly to documented base
`875bddba6538818f2c3c9849e184f40688ad5140`, and produced the expected r2
source pin and checksum.
Both APKs use the already documented `pmos@local-6a8b0868` signing identity.
The main package passed its exact file manifest, AArch64 ELF, desktop, D-Bus,
AppStream, schema, resource namespace, stale-identity and distro Snapshot
ownership-overlap checks. The language package passed its signature, noarch
identity, `install_if`, locale-only payload and main-package non-overlap checks.

| r7/r2 package | SHA-256 |
| --- | --- |
| `advanced-snapshot-0.1.0-r2.apk` | `73d8fd40640a5a73521cc376418c38fae6413abcd450c18193d9568b236a9d18` |
| `advanced-snapshot-lang-0.1.0-r2.apk` | `82cf5d353b7c5fd68ba1ba795a4a1f51ae0ae214d6e88d90f452d5025bd8f37a` |

The r7/r2 offline candidate index SHA-256 is
`96f7d3ff83692ae168219695b3254e9995dcf85b920982fae175d580819e29b3`;
the exact r7/r1 rollback index SHA-256 is
`cfada4dca32fdc325f72cb12f499059a3829c0edaa147ee769b743ed1301ca4b`.
Each repository contains exactly three APKs, including the same accepted
PipeWire r7 package on both sides.

The generation manager now derives its expected operation count from the six
immutable manifest rows. Its original r6/r0-to-r7/r1 three-transition tests
still pass. New install, rollback and simulation tests require exactly two app
operations for r7/r1-to-r7/r2, prove PipeWire remains r7, prove no PipeWire
world identity is created and prove the legacy unpin path is skipped. All APN,
Messages, generation-manager and image-metric tests pass, as does a staged
`make install` containing both immutable manifests. Phone installation and
visual/touch acceptance remain separate gates and are not claimed here.

## Waydroid r35 GPU/JPEG acceptance

Date: 2026-08-25. The final ARMv7 Waydroid bundle was built from libcamera
0.7.2 with the Android patch series `0001`–`0004` and
`WAYDROID_SOFTISP_GPU=enabled`. The package and manifest hashes are:

```text
waydroid-camera-r35-gpu-final.tar.gz
6d1f03878991825d0dd0edfce5f98b9825dfd9e15f2aae59ad0fcde1ed4c8f6f
waydroid-camera-r35-gpu-final.sha256
2ff519dcf00bc09ebecb575260f88998f83e76fb1e6ff5cd3c9b8640b3a93b7a
```

The bundle was copied to the phone, verified against both hashes, extracted
into `/var/lib/waydroid/overlay`, and checked with the 13-file manifest. A
pre-install backup was retained at
`/var/lib/waydroid/backups/camera-r34-before-r35-20260825T171946`; its tarball
SHA-256 is
`35bfccfe44189a244c5f2bc34b4ea6563b4a3838f9dfde5db1580e85293ed1d2` and its
manifest SHA-256 is
`e6f0201b2a109e41720ff6a2f0a247ab45ec8e6f7d869f664b2dfc5eb70e8ee1`.

The clean Camera2 probe ended with:

```text
PROBE_DONE valid=3 total=3
```

Camera 0 returned AF states `[3, 4]`, camera 1 truthfully returned fixed-focus
state `[0]`, and camera 2 returned AF states `[3, 5]`. All three passed YUV,
private, JPEG, EV movement and sensor-timing checks. A clean Aperture capture
then produced a valid Exif JPEG at 1600x1200. The framework log contained
`Aperture: Photo capture succeeded` and no `fixUpHidlJpegBlobHeader` or
`Image_getBlobSize` warning. The provider remained stable with both the legacy
and external camera service processes present.

The r35 GPU benchmark was materially faster than the earlier CPU-only
1600x1200 path: representative GPU runs were about 36.8–42.1 ms/frame, while
the earlier CPU run was about 125 ms/frame. These are processing benchmarks,
not a claim of Android vendor-camera image-quality parity. Running the probe
while Aperture owns CAMSS can still produce a transient media-link-busy result;
the accepted probe was rerun with camera clients stopped.

## Waydroid SIGPIPE-safe provider build

Date: 2026-08-25. Android log and host `dmesg` evidence showed
`vendor.camera-provider-2-4` repeatedly receiving signal 13 when the
libcamera software-IPA Unix socket peer closed. The new patch changes the
header `send()` and payload `sendmsg()` calls to use `MSG_NOSIGNAL`, allowing
libcamera's existing `EPIPE` error path to tear down the affected request
without terminating the provider process.

The patch applies cleanly to the reviewed libcamera 0.7.2 source and the
ARMv7 GPU bundle compiled all 197 targets plus the final install/signature
steps with `WAYDROID_SOFTISP_GPU=enabled`. Reproducible artifacts from this
build are:

```text
patch 0005: cde362b958fac2d7570af4037971788e90b68d7dd8a5e22566c463f82adeefda
waydroid-camera-sigpipe-r35-gpu.tar.gz: bafb6c3f37d4a7d4256985bc5de45e45073b5ad6fa41cc1e9341fd212d835e39
waydroid-camera-sigpipe-r35-gpu.sha256: d8fc2b25eaa93eb40f7fd4a029416cde18f9fb1dc5e8bae2780e64388ef41319
```

Phone acceptance is pending. The old r35 container was stopped, but its
overlay mount entered an uninterruptible I/O wait during the installer backup
before the installer printed a backup path; no reboot or forced overlay
replacement was performed in this run. After the phone is responsive again,
verify the old backup/overlay state, install this matched bundle with the
guarded installer, and repeat the non-invasive provider lifecycle check
before calling the patch accepted.

The host-side regression test for this failure mode now passes as part of
`make test`: it supplies a representative `/proc/self/mountinfo` fixture,
requires the installer to refuse the mounted-rootfs case, then confirms the
same dry-run proceeds when the fixture is clear. This guard is committed in
`fcb930d` and prevents the previous deadlock from being silently repeated.

## Waydroid reduced-preview-source candidate

Date: 2026-08-25. The Android Camera3 path was measured processing a common
1600x1200 private preview at about 36.8–42.1 ms/frame through the Mesa GPU
software ISP. Patch `0006` preserves the requested Android buffer dimensions,
but selects a supported 1280x960 source for 4:3 previews and 1280x720 for
16:9 previews. This reduces debayer work without changing the still JPEG
source size; ratio-preserving libyuv scaling fills the requested preview
buffer.

The patch applied cleanly after `0001`–`0005`, and the ARMv7 GPU build passed
all 197 compile targets plus the final install/signature pass. The package and
manifest were generated by `scripts/package-waydroid-camera`:

```text
patch 0006: a4f892e19efdf6fc3fac89518689d63eb2ba1bcf4ee7b68a069119184b06b987
waydroid-camera-preview-r35-gpu.tar.gz: 617a3bfc56fa41becaae4c14d75aca55ab4914ef745e75449f83448ee749f9ea
waydroid-camera-preview-r35-gpu.sha256: f5dd6bfe15f26ff8750fdd8ffc2a22061514339cf3527735f091fb95ba14c186
```

This candidate was not installed. The phone's old Waydroid rootfs mounts and
uninterruptible storage I/O were still present, so remote installation would
have repeated the previously blocked overlay backup. Runtime acceptance is
pending a physical reboot, a zero-stale-mount check, the guarded installer,
the three-camera Camera2 probe, JPEG capture and a before/after preview timing
comparison. The probe now requests a large private preview when available and
records Camera2 delivery timing (`privateSize`, `privateFps` and
`privateIntervalMs`) without turning an FPS value into a pass/fail threshold.
The candidate must be rolled back if any required stream, JPEG or provider
stability check regresses.

## Ordinary update safety gate

Date: 2026-08-25/26. `scripts/pmos-safe-upgrade` was added as the first
VibeMarketOS update layer. Its default simulation allows an unrelated mock
`busybox` upgrade, applies that same safe transaction with the cached index,
refuses a simulated `libcamera` upgrade before the apply phase, and alarms if
the apply operation list drifts from the simulation. The regressions are
covered by `tests/test-update-guard.sh` and the complete `make test` suite
passes. This is a transaction-text safety gate, not a substitute for a signed
repository or the manifest/health-gated camera generation manager; no update
was applied to the phone during this validation.

## Advanced Snapshot r7 camera generation

Date: 2026-08-26. The synchronized Advanced Snapshot source was built for
AArch64 with pmbootstrap 3.11.1 from recipe release `0.1.0-r7`. The package
was signed with the persistent development key whose public-key SHA-256 is
`31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6`.
Artifact validation passed for both the main and language packages, including
signature, AArch64 ELF, file ownership, D-Bus, AppStream, GSettings and
resource-namespace checks.

The new generation is `camera-r7-r5`: it keeps PipeWire SPA r7, upgrades
Advanced Snapshot r4 to r7, and retains r4 plus the language package as the
rollback. Both candidate and rollback repository indexes are signed and the
manager now verifies those index signatures before invoking apk. The exact
package hashes are recorded in `data/camera-generation-r7-r5.psv`.

This generation is staged in the local ignored artifact directory and was
published as the
[camera-r7-r5 development prerelease](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/camera-r7-r5).
The archive SHA-256 is
`d3f637a4fa54186d853f48e13b0ea97725be16805549338ed6977c32e992b0d4`.
It has not been installed on the reference phone. Physical health-gate,
launch, preview, photo, video, rollback and reboot acceptance remain pending
recovery.

## Remaining validation

A normal reboot test has not yet been performed for this repository revision.
NetworkManager profile persistence and autoconnect were verified with a manual
down/up cycle; boot-time reconnection must be recorded separately after an
explicitly approved reboot.

The r24/r7/r3 native userspace stack, Advanced Snapshot r1 and the previous
r35 Waydroid GPU/JPEG overlay are installed and required no phone reboot. The
reduced-preview-source candidate is staged offline only. Exact r6/r0, r23 libcamera
and older r20/r6/r2 rollback APKs remain staged in separate user-owned offline
repositories.
An unlocked Snapshot touchscreen tap, focus indicator, saved full-resolution
photo, video, flash expectations, screen-off/on, suspend/resume and an actual
exact-version rollback test remain to be recorded. Android-level HDR, temporal
denoise, calibrated CCM/lens shading and computational fusion remain
unimplemented and are not represented as completed work. The Snapshot GUI
remains below the requested Android-camera control level and is the next camera
workstream. Waydroid needs
broader third-party camera-app, Play Store and lifecycle testing.

## Host diagnostics and current device gate

Date: 2026-08-25. The reproducible host-side diagnostics in
`oneplus6t-pmos-fixes` are now committed and pushed through `9faaed0`:

- `pmos-check-location` reports the discovered ModemManager modem,
  `--location-status`, `--location-get`, GeoClue service state and
  NetworkManager devices without enabling GPS or changing providers;
- `pmos-check-nfc` inspects controller/rfkill exposure and reader tools without
  polling by default;
- `pmos-check-power` reports battery, CPU policy and suspend information
  without applying a power policy; and
- `pmos-check-waydroid-health` reports rootfs mounts and kernel I/O pressure,
  and only calls the read-only `waydroid status` command when `--status` is
  explicitly requested.

The complete `make test` suite and staged `make install` validation pass for
all four reports. Their fixture tests do not require a phone, modem, NFC tag or
Waydroid container.

The reference phone was checked read-only over SSH on this date and reported
`io some avg10=100.00`, `full avg10=98.81`, load averages above 57 and five
mounts under `/var/lib/waydroid/rootfs`. After the report was reordered to emit
proc/mount evidence first, it completed remotely and recorded
`overlay_precondition=blocked-rootfs-mounted`.

A read-only process audit found the container service still `active` while the
Android session was `inactive`. The five mounts were the system image, rootfs
overlay, vendor image, vendor overlay and `waydroid.prop` loop mount. Several
historical helper commands remained in uninterruptible `D` state, including two
`install-waydroid-camera` invocations, a `waydroid container start`, and four
old reboot attempts. A bounded `sudo systemctl stop waydroid-container.service`
attempt itself blocked in the same storage wait; it was interrupted, and the
service/mount count remained unchanged. A second attempt to signal only those
stale helper PIDs could not pass through the blocked sudo path, so no process
or overlay state was assumed to have changed.

The reproducible `--processes` mode now records the same seven stale helpers
on the phone: two installer shells, one container-start command and four old
reboot commands. It emits their command lines as evidence but does not send
signals. This report is the required recovery baseline before another
physical reboot or any overlay operation.

Runtime acceptance therefore still requires physical recovery,
`rootfs_mounts=0`, `overlay_precondition=pass`, the guarded preview candidate
install, and the camera/location/NFC/power/audio acceptance sequences above.

## Recovery attempt and timed power baseline

Date: 2026-08-25. The phone remained reachable at `172.16.42.1` over the
OnePlus 6T USB CDC-NCM gadget, but new SSH connections stopped at the banner
while the five Waydroid mounts and saturated I/O state remained. A normal
systemd reboot and a forced systemd reboot both waited on the same blocked
teardown. The direct reboot path then dropped SSH but did not produce a
confirmed new login; no partition, boot slot, firmware or overlay write was
performed during recovery.

The host identified the exact USB device as `ID_MODEL=OnePlus_6T` on
`3-3.3:3`, performed one logical USB reset and one authorization
detach/reattach, and confirmed that the NCM interface re-registered. These
operations did not clear the phone-side mount deadlock. A physical power
cycle/reboot remains required before another remote installer attempt; the
phone must be checked again from a fresh SSH session rather than inferred from
the host USB link.

The USB product database labels the same `18d1:d001` device as “Nexus 4
(fastboot)”, but its live descriptors expose only a CDC-NCM control/data
interface, not fastboot endpoints. The working `172.16.42.2/16` host link and
`172.16.42.1` ping therefore prove that postmarketOS networking is alive; an
empty `fastboot devices` result is expected in this state. Do not try to flash
or issue fastboot commands based on that product-database label. This matches
postmarketOS's [documented NCM networking gadget behavior](https://postmarketos.org/edge/2023/10/29/rndis-ncm/).

The new read-only `pmos-measure-power --duration 0` sampler also collected a
baseline without changing policy:

```text
capacity_percent=97
current_now_ua=0
voltage_now_uv=4336000
temperature_tenths_c=276
status=Not charging
```

This is a one-sample baseline, not battery-life acceptance. Repeat it at idle,
camera preview, modem activity and screen-off after recovery.

## 2026-08-26 recovery boundary recheck

The host rechecked the reference link without sending commands to the phone.
`172.16.42.1` still answered one ICMP packet, but the OnePlus was not present
as a USB device, `fastboot devices` was empty, and `adb devices` showed only
the separately connected Pixel test device. TCP port 22 accepted a connection
but did not send an SSH banner within a bounded 25-second exchange; the
alternate service ports refused connections. This is consistent with a
phone-side userspace/storage hang or an incomplete recovery state, not a
healthy SSH session.

No reboot, install, overlay copy, partition, boot-slot, firmware or fastboot
operation was attempted during this recheck. Do not use the surviving ping or
TCP accept as an installation health signal. A physical power/recovery cycle
is still required, followed by a fresh USB identity check and the
`rootfs_mounts=0`/`overlay_precondition=pass` gate before any device-side
camera or Waydroid work.

## Waydroid isolated preview and recording-template probe

Date: 2026-08-26. The Camera2 probe now has five explicit performance
profiles:
the unchanged `full` acceptance run, `preview` for a private/
implementation-defined stream only, `preview-yuv` for private preview plus YUV
without JPEG, `surface` for the displayed `TextureView`, and `record` for the
same displayed `TextureView` driven by Camera2's `TEMPLATE_RECORD`. The latter
four avoid confusing a multi-stream validation load with the frame rate a
camera application can receive from one preview or recording-template stream.
The `record` profile does not invoke an Android encoder or create a file;
native video capture still needs its own playback test. Unknown profile values
fall back to `full`.

The updated Java source compiled and packaged successfully with the local
Android SDK platform 34 and build-tools 36.0.0. The generated debug APK was
verified by `apksigner`; its hash is intentionally not a release artifact
because the probe build creates a local debug key when one is not present.
`make test` also passed, including shell syntax, installer guards, update
safety and Python checks. Device acceptance is pending physical recovery.

After `rootfs_mounts=0` and `overlay_precondition=pass`, run the profiles in
order and compare `privateFps`/`privateIntervalMs`:

```sh
waydroid shell am force-stop dev.lolren.waydroidcameraprobe
waydroid shell am start -n \
  dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile preview
waydroid shell cat \
  /data/user/0/dev.lolren.waydroidcameraprobe/files/result.txt
```

Repeat with `preview-yuv`, then the default full probe. A slow private-only
result implicates the provider/software ISP, Waydroid compositor or device
mode; a large drop only after adding YUV/JPEG implicates multi-stream
conversion pressure. Run `record` after `surface` to distinguish a drop in
Camera2's recording template from a generic displayed-surface drop. The GPU
path still performs a synchronous RGBA readback and NV12 conversion for
explicit YUV/video-encoder streams, so it must be benchmarked on this phone
before the GPU configuration is changed or declared faster.

## Waydroid conditional-mipmap candidate

Date: 2026-08-25. Static review of the EGL software-ISP path found that the
filtered RGB scaler regenerated a complete mipmap chain on every frame, even
when the cropped source was kept at the same size or enlarged for the Android
preview. The new Android-only patch `0007` records the scale geometry during
configuration and calls `glGenerateMipmap()` only for a true downscale. The
explicit five-tap scaler remains active in all cases, so the change does not
remove the configured sharpness pass.

The patch applies cleanly after the existing generic series and Android
patches `0001`–`0006`; `git diff --check` passed on the complete reviewed
libcamera tree. Its SHA-256 is:

```text
0007-android-avoid-needless-preview-mipmap-generation.patch: acc7675cc09e4bfdd48a0184c71422200ac39f72abbe0717daab19b8e16b2086
```

The exact ARMv7 GPU build also compiled all 197 targets and completed the
staging/package/signature pass. The staged library hashes and package hashes
were:

```text
camera.libcamera.so: 813bd3d6b9f7a9febacc5c0fd8449eb04b9b127faed2b3de33ddfea2a6780376
libcamera.so: 239211b85eb490ed0c35c53f4e8be07d3772b0bfb4b46a03c8c1c5ced76d52f5
libcamera-base.so: fe16feb04ec18b1463a742ac98225b93abec3d01c3760b3bc91e00c724287cc0
ipa_soft_simple.so: 709e83e4c7009fadbfc60b4db57c4c38a80bd0a14772068b48920d302653ddf8
waydroid-camera-mipmap-r35-gpu.tar.gz: 6543d7c1d51bb8f60799aa487d7eb56b8408718de37778add7596d2219df48ac
waydroid-camera-mipmap-r35-gpu.sha256: 9c14fc6b54533c5eb38eef2d10563b0764e3df0afe1ad12caee1aaaa53a75fdf
```

No package was installed for this candidate because the phone was still
unreachable for SSH health checks after its earlier Waydroid rootfs/I/O
blocker. The ARMv7 build was performed offline against the preserved
source and dependency prefix. After
physical recovery,
rebuild a fresh matched bundle with `0007`, run the isolated `preview` and
`preview-yuv` profiles against the old baseline, and keep the candidate only
if frame delivery and image output remain healthy. The synchronous RGBA
readback and NV12 conversion are unchanged, so this is an incremental GPU
optimization rather than a complete Android-camera performance fix.

## Waydroid redundant-clear candidate

Date: 2026-08-25. A second static pass over the Android EGL software-ISP path
found two `glClear(GL_COLOR_BUFFER_BIT)` calls immediately before full-screen
Bayer and RGB-scaler draws. Both draws cover the complete active framebuffer,
so the clears duplicate full-frame writes on every preview frame. Patch `0008`
removes only those clears; shaders, mipmap policy, buffer formats, error
checking and fallback paths are unchanged.

The patch was generated from the reviewed tree after `0007`, passed
`git diff --check`, and builds cleanly with the checked-in ARMv7/API-33 GPU
helper. The patch and exact package hashes are:

```text
0008-android-skip-redundant-fullscreen-gpu-clears.patch: 1be009b40d0952932920acb54dd4b498962b378e794c0ed2a0248141414c8382
waydroid-camera-clears-r35-gpu.tar.gz: 3d964ba9c305c0cb232dd743510b3882a11a443fb1ddc2d59f38225001cf8650
waydroid-camera-clears-r35-gpu.sha256: e295a32607f02133767e391eaa3abc3d2f9ed71ccb842ec17f6add8f6ea47f0b
camera.libcamera.so: 2b3e46a1ca3863e26afff20e483138eb7e0f8089a87d91ceaf83cc043faa9210
libcamera.so: 11842c16f8cd2a8e996f3cb5f3cd81f83e982f802c59ec0390f4164ed8f6be23
libcamera-base.so: ad72054e6f672ca9af7a952672d8d0d2fca119517523dd5114953e132c76d222
libc++_shared.so: 7ce65fd0fdd49236bc2ee618f6968dbb3fca46434845f563f2bb4c994878853e
ipa_soft_simple.so: 14fe5f02fbcb4fc85a555063c6d3c33ea63ddd5b90dff6651a126d576d0581c0
soft_ipa_proxy: 34843d6ad7bf859045d40dbc7c06956320d894390a48ea6d40ed5a5843d4654a
```

The build compiled all 197 targets and completed staging, signing and
manifest generation. No runtime installation was attempted: the phone's
Waydroid rootfs/I/O deadlock still fails the overlay health gate. After a
physical recovery, install this bundle only after
`rootfs_mounts=0` and `overlay_precondition=pass`, then compare the isolated
`preview` and `preview-yuv` profiles with the accepted r35 baseline. Keep the
candidate only if frame delivery, JPEG output and provider lifecycle remain
healthy.

## Waydroid NV12-fence candidate

Date: 2026-08-26. Static review of the Android GPU software-ISP path found
that the NV12 branch synchronously reads the rendered RGBA intermediate with
`glReadPixels()`, converts it into the CPU-mapped Android buffer, and then
unconditionally calls `glFinish()` a second time. Patch `0009` skips that
post-readback finish only for NV12 output. Direct RGB DMA-BUF output retains
the finish because its emitted buffer still contains GPU writes.

The patch changes no shader, format, buffer ownership or CPU conversion code.
It applies cleanly after `0001`–`0008`; the host fixture test in
`tests/test-waydroid-gpu-sync.sh` verifies that the unconditional call is
replaced by an `outputIsNv12_` guard. This is an incremental performance
candidate, not a claim that Android preview has reached native-pMOS frame
rates.

The complete ARMv7/API-33 GPU build passed all 197 compile targets and the
staging/signature pass. The exact candidate artifacts are:

```text
0009-android-skip-redundant-nv12-gl-finish.patch: 77386e4a76c4adbbeef5dae5498e25eef7c96904d11d600e0962961211a9df79
waydroid-camera-nv12-finish-r36-gpu.tar.gz: f2d47df77998a489d51ccc66661882dbd6b844282a8475e7730076a2dd7d147a
waydroid-camera-nv12-finish-r36-gpu.sha256: a8b25d69d09a069696e20caad44b135a67e038885e9c9a1be8cb207703ac0ab5
libcamera.so: b97540dedfafe4319835a989452ac8ccc3786a7cc53159c7669fb127a7b60691
```

The patch has not been installed on the phone. Runtime acceptance requires a
healthy Waydroid preflight, a fresh matched ARMv7 bundle, and before/after
`preview` and `preview-yuv` measurements. Keep the candidate only if all
three cameras, JPEG capture and provider lifecycle remain healthy; otherwise
use the previously accepted r35 bundle.

## Waydroid RGB private-preview candidate

Date: 2026-08-26. The Android Camera3 path previously mapped
`IMPLEMENTATION_DEFINED` preview streams to NV12. That path is compatible with
YUV and encoder consumers, but it requires the GPU to render an RGBA
intermediate, synchronously read it back with `glReadPixels()` and convert it
with libyuv on every frame. Patch `0010` selects an RGBX/XBGR buffer for
texture-only private streams. The GPU then imports the real DMA-BUF fourcc and
writes the RGB preview without the NV12 readback/conversion; explicit YUV and
video-encoder streams remain on NV12. RGB output keeps the GPU completion fence,
and the generic RGB post-processor is used only for same-size mapped streams.

The candidate was built in a clean ARMv7/API-33 Android configuration with the
same NDK, dependency prefix and `softisp-gpu=enabled` settings as the r35/r36
bundles. The full Meson build, Android HAL link, software IPA, proxy and IPA
signature completed successfully. The patch applies cleanly after 0009 in a
fresh libcamera worktree and `git diff --check` is clean.

Reproduction identifiers and artifacts from this build are:

```text
libcamera source candidate commit: 09f350cfef887172669ebc9c1378e16c064382e0
0009 source commit: b296650f (published as Android patch 0009)
0010-android-route-private-preview-to-rgb.patch: 6bcc844d7330fbeb5d5f3c64abde788f22e58b0f17aba8057df58c3a90ceef72
waydroid-camera-rgb-r37-gpu.tar.gz: 88a9f2be8ac90f58c0428d82bd71ca4751636a56cc883bd8ecdd22ca87d14b3e
waydroid-camera-rgb-r37-gpu.sha256: 46256be3808f91306daa32338aaddda25594067ef9dbebe89bbaeddcad36184a
camera.libcamera.so: 1b8dfa9350a5439d65cfbf906dd856ba80ac2f7544729b80a02bd150d3c94702
libcamera.so: 430a5233ece30bc5bc4a01866bcb1f0dd769a8241842a81d75dcfd04617493c3
libcamera-base.so: c2ba957c78e4f889699aae317571c7d0c93f67405a8b0e3ca2cff1b7b6e4f1ec
ipa_soft_simple.so: 0b372cc7f0b47a5eb2a232d8c0ab26b5968693cd834bf4bc7d318101315941dd
soft_ipa_proxy: ba0de00f5c4ca21abe281ce05d017dcd1259a140d5516debc7087b52f69d7a70
```

This is a performance candidate, not a phone acceptance claim. After the
health gate reports `rootfs_mounts=0` and `overlay_precondition=pass`, install
the bundle only as a new backup-protected generation and compare `preview`,
`preview-yuv`, `surface` and `full` against r35. Check all three cameras,
saved JPEG colour/order, exposure and focus, then exercise provider stop/start.
Rollback to the r35 bundle if RGB import fails, colours are swapped, buffers
are corrupted or lifecycle stability regresses. Do not replace the accepted
baseline merely because a host build succeeded.

The archive and its matching manifest are published in the
[Waydroid camera r37/r38 development release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r37-r38).
The release assets were downloaded again and compared byte-for-byte with the
locally verified artifacts; the r37 archive hash is
`88a9f2be8ac90f58c0428d82bd71ca4751636a56cc883bd8ecdd22ca87d14b3e` and the
r38 archive hash is
`045962846fa9bc21aedbf8e62b33c332aba1ba847f1f5c7aacd298e6f6055df6`.

## Waydroid display and recording-template probe

Date: 2026-08-26. The Camera2 probe now accepts `surface` and `record` profiles
in addition to `preview`, `preview-yuv` and `full`. It presents the
implementation-defined
stream on a real Android `TextureView` and counts `onSurfaceTextureUpdated`
callbacks. Results identify this with `privateTimingSource=surface`; the
existing profiles continue to report `ImageReader` delivery. This separates a
slow Camera3/software-ISP provider from a slow Waydroid surface/compositor path
without depending on a third-party camera application. After the timing
threshold, `surface` also performs one asynchronous `PixelCopy` into an
ARGB_8888 bitmap and records `surfaceRgbMean` and `surfaceRgbRange`. This is
colour-order and blank-surface evidence only; it is deliberately outside the
repeating capture path and is not an image-quality acceptance test. The
`record` profile uses Camera2's `TEMPLATE_RECORD` with the same `TextureView`,
prefers an advertised fixed 30 FPS range when available, records the selected
range, and falls back only to another advertised range; it does not invoke an
encoder or create a file. Surface timing callbacks are coalesced before their
samples are dispatched to the camera worker, preventing a UI callback backlog
from inflating the reported rate.

The updated APK compiled and verified with Android SDK platform 34 and
build-tools 36.0.0. The host runner and full fixes test suite pass, including
the surface- and record-profile command checks. This is diagnostic
instrumentation only; it does not change the native camera stack or Waydroid
overlay.

The host-side `pmos-compare-waydroid-camera-probes` helper is also covered by
the fixes test suite. Given two saved results from the same profile, it checks
camera identity and validity and reports per-camera FPS/interval changes plus
surface RGB evidence. It does not turn performance alone into acceptance; the
candidate still requires the image, JPEG and provider lifecycle checks above.

## Waydroid RGB native-release-fence candidate

Date: 2026-08-26. The RGB private-preview candidate still completed the GPU
render with a synchronous `glFinish()`. Android can carry a native release
fence for a GPU-written buffer, so patch `0011` exports an
`EGL_SYNC_NATIVE_FENCE_ANDROID` fence when the EGL implementation exposes the
required functions. The RGB `FrameBuffer` publishes that fence to Camera3;
the mapped RGB post-processor consumes and waits for it before CPU access.
When the extension is absent or cannot create a fence, the previous
synchronous `glFinish()` path remains active. YUV and video-encoder streams
are unchanged.

The candidate was built from the r37 RGB source with the same clean ARMv7/API
33 configuration, NDK, dependency prefix and `softisp-gpu=enabled` settings.
The fresh build completed all 198 compile/link targets, regenerated and
verified the software-IPA signature, and staged the runtime files. Patch
`0010` followed by `0011` applies cleanly in a temporary worktree and
`git diff --check` is clean. No device installation or FPS improvement is
claimed: the extension and fence behavior must be checked on the phone.

Reproduction identifiers and artifacts from this build are:

```text
libcamera source candidate commit: f29a0c6a213048113e0decce6f1729ce5e7365d7
0010-android-route-private-preview-to-rgb.patch: 6bcc844d7330fbeb5d5f3c64abde788f22e58b0f17aba8057df58c3a90ceef72
0011-android-export-native-rgb-fence.patch: c8ac2b72bf100d5a457c9fc8738ddd02fe46804733a4ef4ac2bd4e95c7f58b83
waydroid-camera-rgb-r38-gpu.tar.gz: 045962846fa9bc21aedbf8e62b33c332aba1ba847f1f5c7aacd298e6f6055df6
waydroid-camera-rgb-r38-gpu.sha256: 15c9f9ec2b1663dbf1a380b8ada4129305b097ae2bde86705dafa44a6049462e
camera.libcamera.so: 3c65c40f7a3aea6ee5e7eb4116c492852a5783588f35b31650f1f11ac4d0acf7
libcamera.so: 76b6db86d2a56eef4bd0c639af4bf167d186787e02c4378dce5eba0fc0470912
libcamera-base.so: c2ba957c78e4f889699aae317571c7d0c93f67405a8b0e3ca2cff1b7b6e4f1ec
libc++_shared.so: 7ce65fd0fdd49236bc2ee618f6968dbb3fca46434845f563f2bb4c994878853e
ipa_soft_simple.so: 0b372cc7f0b47a5eb2a232d8c0ab26b5968693cd834bf4bc7d318101315941dd
soft_ipa_proxy: ba0de00f5c4ca21abe281ce05d017dcd1259a140d5516debc7087b52f69d7a70
```

This is a new, uninstalled generation. After the health gate reports
`rootfs_mounts=0` and `overlay_precondition=pass`, install it only with the
backup-protected generation installer. Compare `preview`, `preview-yuv`,
`surface` and `full` against r35/r37, verify all three cameras, saved JPEG
colour/order, exposure and focus, and exercise provider stop/start. A missing
EGL extension should be reported as the synchronous fallback; a stalled
fence, corrupted buffer, colour swap or lifecycle regression requires rollback
to the previous generation.

The archive and matching manifest are published alongside r37 in the
[Waydroid camera r37/r38 development release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/waydroid-camera-r37-r38).

## Full I/O-pressure overlay guard

Date: 2026-08-26. The original preflight considered only PSI `some` pressure,
which could incorrectly pass when the `full` line showed that every non-idle
task was blocked on storage. The health report now records both
`io_some_avg10` and `io_full_avg10` and requires both to be exactly zero. The
installer repeats the same fail-closed check, including refusal when the PSI
file or either line is unavailable.

The host regression suite covers a clear fixture, a mounted-rootfs fixture and
a clear-rootfs fixture with `some=0.00` but `full=100.00`. `make test` passed;
the latter is classified as `overlay_precondition=blocked-i/o-pressure` and
the installer refuses it before reading or writing any overlay target.

## Fresh USB/userspace recheck

Date: 2026-08-26. A new read-only check reproduced the same boundary after
the repositories were synchronized: `172.16.42.1` answered ping, TCP port 22
accepted a connection but did not send an SSH banner within eight seconds,
`fastboot devices` remained empty, and the USB configuration still exposed
only CDC-NCM control/data interfaces. No reboot, USB reset, overlay access or
flash operation was attempted. The phone therefore still requires a physical
power recovery before the health report or any runtime acceptance can resume.

## Host transport-report checkpoint

Date: 2026-08-26. The new host-side
`scripts/check-device-transport` command reproduced the same boundary
without authentication or device mutation. It identified the USB device as
`OnePlus_6T` with driver `cdc_ncm`, confirmed the host address and ping,
confirmed that TCP/22 accepted a connection, and classified the missing
`SSH-2.0-*` banner as `network-up-ssh-not-speaking`. It counted no fastboot
devices and did not classify the separately attached ADB device as the
OnePlus. Fixture coverage, output-overwrite refusal, shell syntax and the
complete `make test` suite passed.

## Waydroid GAPPS verifier

Date: 2026-08-26. The fixes package now includes
scripts/check-waydroid-gapps and the pmos-check-waydroid-gapps symlink. The
helper is deliberately read-only: it records Waydroid status, Android release
and ABI information, then checks the package paths for Google Play services,
Google Services Framework and Play Store. It returns gapps=verified only when
all three paths are present. It does not initialize images, start or stop
services, alter the camera overlay or include Google files.

The fixture test covers a verified Android 13 ARMv7 result, refusal to
overwrite an existing report and a missing Play Store package. The complete
make test suite and staged make install validation passed. The image-change
procedure, hash-recording requirements and post-initialization camera
reinstallation gate are documented in docs/WAYDROID-GAPPS.md. The current
phone remains blocked at the physical-recovery gate, so no GAPPS image was
initialized and no runtime package result is claimed.

## Display and brightness diagnostic

Date: 2026-08-26. The fixes package now includes
`scripts/check-display` and the `pmos-check-display` installation symlink. It
collects DRM connector/mode state, backlight values, the kernel command line
and filtered display-related kernel messages without writing sysfs, changing
brightness or restarting the compositor. Fixture tests cover an active
1080x2340 connector, readable WLED backlight values, display error lines,
missing hardware and refusal to overwrite an existing report.

The pinned OnePlus device definition already contains the SDM845 panel
initialisation workaround `console=ttyMSM0,115200`; this is a boot-race
workaround, not a validated fix for brightness-triggered static. The phone is
still physically wedged, so no new display-driver candidate has been installed
and no static-line regression has been re-tested.

## Waydroid location-provider capability boundary

Date: 2026-08-26. The location bridge now creates a test provider with only
the capabilities it can populate through Android's shell interface. It sends
latitude/longitude and parsed accuracy, while leaving altitude, speed and
bearing support unadvertised; no location field is fabricated. This keeps the
mock-provider result honest for map applications and preserves the explicit
warning that it is not a native GNSS HAL.

The four location-bridge tests, Python compilation and complete `make test`
suite pass. The change is still source-only: the phone's physical recovery
gate prevents native GNSS, GeoClue, Waydroid location and map acceptance from
being claimed.

## Advanced Snapshot r8 capture-safety candidate

Date: 2026-08-26. Advanced Snapshot commit
`d1e4831ad809270e3f3e0db1f41dda5f2e3d96a3` adds three defensive fixes: failed
or empty non-local capture results are rejected before gallery insertion,
non-finite or unusable camera zoom limits cannot trigger an invalid clamp, and
unknown orientation values are ignored safely. The source repository pushed
the commit and its postmarketOS recipe was bumped to package revision r8.

The clean pinned GTK Docker build passed `cargo fmt --check` and all 15 Rust
tests (6 application and 9 Aperture). A clean pmbootstrap AArch64 build
produced and the Advanced Snapshot package validator accepted:

```text
advanced-snapshot-0.1.0-r8.apk: becc4bc1a734af22b28b7dde7f47c792af6386a93c3b24f2b53bdb47bebc70dd
advanced-snapshot-lang-0.1.0-r8.apk: f615e75c29579bf877e611a10178021936ab5f63388e9d0f9d041d39b0e56c77
camera-r7-r6 archive: e97741f0d3c028c6ca546fd5ff71da23b22c50b905fb6cde8f7a1e6678730996
```

The signed `camera-r7-r6` generation keeps PipeWire r7 unchanged and retains
the r7 app pair as rollback. It is an opt-in, uninstalled candidate: the phone
still has no usable SSH/ADB/fastboot runtime transport, so no device camera
acceptance or claim of fixing the observed hardware preview crash is made.

## Advanced Snapshot r9 save-feedback candidate

Date: 2026-08-26. Advanced Snapshot commit
`ec9f03db6177b8c0ee5fda826668fbbce59d9423` changes the completed-capture
callback to report `Could not save photo` when the pipeline returns no usable
file. It does not change sensor controls, kernel code, PipeWire, libcamera or
Waydroid behavior. The postmarketOS recipe is package revision r9 and pins
the GitHub archive SHA-512
`8e0c20384443b06251affc932ccca0e93929cc31a2cadc473e0fb6606725801ba7775711f1ad926a162bb23c0c5b5e850d139ae81aa519447ee759a3099b5125`.

A clean pmbootstrap AArch64 build ran the application checks (6 tests) and
Aperture checks (9 tests). The final pmbootstrap repository-index update also
reported pre-existing untrusted staged r7/r8 packages, but the r9 APKs were
created, signed and passed the independent package validator:

```text
advanced-snapshot-0.1.0-r9.apk: 9583bfe6e286cbcb6bcda397d817554d09726f9cf29ad505a901803c3d35a555
advanced-snapshot-lang-0.1.0-r9.apk: 59c60305a08d352ddc3fc70c881939e54c05c8e329aa6d6ba1339b5ecfdb6bfa
camera-r7-r7 archive: 09d291bb92ab5027abbc74677c48a2ec304ee1041e48d43e1cc7f202dc7295b5
```

The signed `camera-r7-r7` generation keeps PipeWire r7 unchanged, retains the
r8 app pair for rollback and is opt-in. It is not hardware-accepted because
the reference phone still has no usable SSH/ADB/fastboot runtime transport.

## Advanced Snapshot r10 adjustment-serialization generation

Date: 2026-08-26. Advanced Snapshot commit
`2a9763b8f42c1bb755a507de1cc49ed3c8f09a77` serializes and cancels image-
adjustment helper processes. A newer Exposure, Colour, Contrast or Detail
request invalidates the older generation; camera switches, page teardown and
stream stop also invalidate it. Stale completion callbacks are ignored, which
prevents rapid slider movement from applying old values after a newer request
or keeping a dead helper attached to the camera page.

The r10 source archive SHA-512 is
`ebb1e7818dd9777a5b794ba0667cf449957949a0f3d6e4cb014f12f85538b2d9b9dfad9fe5ec700e2c3accbd6e555cfc457f7cde78c22a03ef93b060bfc1a5b5`.
The clean postmarketOS edge AArch64/musl build completed with all 15
cross-compiled tests passing (6 application and 9 Aperture), and the
independent package validator accepted both signed APKs:

```text
advanced-snapshot-0.1.0-r10.apk: f832c5b3ae4e96969fccba8c8f563e7ff8a7372e3fef7d9b32dc7d5fb9828eb9
advanced-snapshot-lang-0.1.0-r10.apk: 2756823e3cb3ad68575bbe96d88a20cc99ecdc7440c405ba143baf43fdf99fb9
camera-r7-r10 archive: 0e6533469b381ef11cde8a0d3ab849a0f4f2e131b6b65a14dd1a2deb6d76c34b
public-key: 31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6
```

The signed stage keeps PipeWire r7 unchanged and retains the r9 app pair for
rollback. It is an opt-in, uninstalled candidate: the reference phone still
has no usable SSH/ADB/fastboot runtime transport, so native preview, saved
photo, video, display and rollback acceptance remain open.

## Continuous autofocus reference hysteresis candidate

Date: 2026-08-26. The next libcamera candidate is package revision r25. Its
simple-IPA continuous autofocus monitor no longer promotes the reference on a
single unusually high-contrast window. IMX376 and IMX519 tuning requires three
consecutive high windows and promotes only 20% toward the least extreme one;
contrast-loss decay and the delayed sustained-loss restart remain intact.

`tests/test-af-reference.py` is a deterministic model of this decision
boundary. It passes the isolated-spike, sustained-rise, sustained-loss and
transient-loss cases, and the complete `make test` suite passes. The updated
source patch, tuning hashes and r25 package recipe are embedded in the
reproducible pmaports integration patch, whose SHA-256 is
`e6dfec0857c7d0b74d3b64747ce3ad199b618f0d84b32885c586a602b34ab16b`.
The clean AArch64 build produced these local artifacts:

```text
libcamera-99990.7.2-r25.apk: ccdfaf820ba6362cfbb4dae3ded92eb9e18542afcdde1596eb8bed91e9e7323f
libcamera-ipa-99990.7.2-r25.apk: 11efa3eaa05e00e0921cbf081fb1b1fe8fdd356a4fc1244cbbb13d90fc14608a
```

No physical claim is made: the phone still has no usable SSH/ADB/fastboot
runtime transport, so r25 remains uninstalled pending recovery and live
actuator validation.

## ModemManager formatted location parser

Date: 2026-08-26. The Waydroid location bridge now accepts the two location
formats that a live ModemManager monitor can expose: raw NMEA sentences and
human-readable decimal GPS fields. `ModemLocationParser` joins separate
latitude/longitude lines, carries optional accuracy and altitude metadata, and
resets on a new GPS block or repeated coordinate so a transient partial record
cannot silently combine coordinates from different updates. Out-of-range and
non-finite values are ignored.

The eight fixture-driven bridge tests cover GGA, invalid NMEA, gpsd TPV,
formatted ModemManager records, repeated-coordinate boundaries, invalid
coordinates and both dry-run input paths. Python compilation, `git diff
--check`, and the complete `make test` suite passed. This is a source-only
improvement: no native GNSS fix, GeoClue result, Waydroid injection or map
behavior is claimed until the phone's physical recovery gate is cleared.

## Bounded hardware-flash helper

Date: 2026-08-26. The pMOS fixes tree now installs `pmos-camera-flash`, a
signal-safe helper for writable top-level `*:flash` LED channels. It supports
read-only `--probe`/`--status`, bounded `--pulse`, and explicit `--off`. A
pulse saves every channel's existing brightness, applies the requested level
(halving yellow/amber channels), caps duration at five seconds and restores the
saved values on normal exit or interruption.

`tests/test-camera-flash.sh` uses a temporary white/yellow LED fixture and
covers status, pulse restoration, off and the no-hardware failure path. The
helper is included in `make test`, `make install` and the package recipe. The
Advanced Snapshot UI calls it only for a rear camera, with a default 2.5-second
level-32 pulse, and leaves the setting off by default. Host source and fixture
validation passed; the phone still needs a live LED status/capture test after
SSH/ADB/fastboot recovery. No automatic flash metering, HDR or Android-vendor
image-quality claim is made.

## pmaports r11 recipe and camera-generation synchronization

Date: 2026-08-26. The reproducible pmaports integration patch now carries the
Advanced Snapshot r11 recipe and its bounded rear-flash implementation. It
applies cleanly to pmaports base `875bddba6538818f2c3c9849e184f40688ad5140`
and has SHA-256
`df39e156c3eeb09f4493a2d3a7c46fc3f18264c83703c7d3256f9b3cfb49f9cf`.

A clean pmbootstrap edge AArch64/musl build passed all 15 cross-compiled tests
(6 application and 9 Aperture), and the independent package validator accepted
the signed r11 APK pair for signatures, AArch64 ELF, package content, schema,
AppStream and overlap:

```text
advanced-snapshot-0.1.0-r11.apk: f4dafe29a4682df10b4649fee3110dac419c8179098e0a9762f48a2251cf7c1b
advanced-snapshot-lang-0.1.0-r11.apk: 40a9a822421d5640ce14f1046006bbb5b92b022862d977de0d7d14cf30f2c95a
public-key: 31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6
camera-r7-r11 archive: 840fb638260d979ede9f3b86eea048e6b66948f8c8df9ff97326cb90eb5b572f
```

The signed candidate stage keeps PipeWire r7 and retains the exact r10 app
pair for rollback. It is source/package validated but remains uninstalled and
unhardware-tested while the reference phone exposes CDC-NCM without a usable
SSH banner, ADB device or fastboot transport.

## Display kernel r9 serialized-brightness candidate

Date: 2026-08-26. The Samsung S6E3FC2X01 panel candidate serializes each
brightness DCS write with a mutex, saves the DSI mode flags inside that critical
section, clears low-power mode only for the write and restores the flags on
success or error. The mutex is initialized during panel probe. This is a
targeted race fix for rapid brightness-slider updates; it is not evidence that
all DRM atomic, DPU, compositor or panel corruption is solved.

The source patch applies without fuzz to the pinned
`sdm845-7.1-rc1-r0` Linux tree. Its SHA-512 is:

```text
c5fe9e034cfa358930dbe35bfa562d6556f46c58b692893113ea51a0909c5e78847dda433032412b46288640968d281ce9ad01c77e6711c641e9c3ffa2b7773e
```

The updated pmaports integration patch applies cleanly to base
`875bddba6538818f2c3c9849e184f40688ad5140` and has SHA-256
`6259e171500508a515c71d38fdf2d270221fa8be53196e0d7f4f4724fe50536d`.
A clean AArch64 kernel package build completed through compilation and
produced:

```text
linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk: 6049f30fb9ed0b5576f309720bfd75ea4d8faded4eadf10fc887d3d0a0aeb957
linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk (SHA-512): eede250d35ef4ed27309e87d2251c0c73388bbc020ffef493ba9c469bf940acd4531c1e8b5bd2765913e758b906fb1d5277d921b19e5c2eaa30bfe64b470c038
linux-postmarketos-qcom-sdm845-7.1_rc8 rollback.apk: 232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e
display-r8-r9 archive: 231807afab660e91ad433f8ac9a8a1e284b5d8191b784d57e8890eb9cfd3b6fe
public-key: 31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6
```

The APK and both repository indexes were independently verified with the
development public key. The archive contains only the candidate/rollback APKs,
their signed `APKINDEX.tar.gz` files and `SHA256SUMS`; no private key is
included. `make test`, shell syntax validation and a fresh pmaports
`git apply --check` passed. The candidate remains uninstalled because the
reference phone still has no usable SSH banner, ADB device or fastboot
transport, so physical display, reboot-persistence and rollback acceptance are
open.

## Display kernel r9 fresh local package checkpoint

Date: 2026-08-26. After the first build host lost the remote source download,
the build was repeated using the already downloaded Linux archive whose
SHA-512 is
`94da173aaf74dd33ef8ff9015e92759481cd0da5bd8a1e52c8664fd372d48a1155655001ad2e9d26557733c71ae8bc448e4ebdf1372b8f32159907a35f0306a`.
The pinned source and brightness-serialization patch were unchanged. A clean
pmbootstrap AArch64 build completed and the resulting local APK was signed
and independently verified:

```text
integration patch SHA-256: 144f69cbe3c4b37d44fe0e03fe32c777c25f99ca7d42170e60003cbf05a7ad51
linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk: 488a11f8a473a869a6caa1f5d20c179088018bc531be0848db40f43cc9093efe
linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk (SHA-512): f63bcf8309bf012a667075c2128c60a6b68588deeb23debfa21e21aa8b96127cac967365fde0530b2a4311dbd4775d9050e7fe597bbd9a36d7818f66f9a14769
```

This is a fresh local build artifact, not a replacement for the published
`display-r8-r9` release referenced by `data/display-kernel-r8-r9.psv`; the
installer manifest therefore continues to pin the published APK hash. No
phone package was installed and no physical display, reboot-persistence or
rollback result is claimed.

## Libcamera r26 manual-exposure source checkpoint

Date: 2026-08-26. The standalone
`0017-ipa-simple-Expose-manual-exposure-and-gain-controls.patch` now publishes
standard `ExposureTimeMode`, `ExposureTime`, `AnalogueGainMode` and
`AnalogueGain` controls from the simple IPA. It converts public microsecond and
linear-gain values to sensor units, clamps requests and reports the selected
Auto/Manual modes in metadata. Automatic exposure and gain remain independently
selectable for libcamera clients.

The source patch SHA-512 is:

```text
af4141ed03b1c0647ef55eb1c61ed113933adc82d5651bc39930387bae0c72e717d1bbc24121c775c9b8baa60c5271f6d94029e4e756bbfe3b1ecdf3a94f6172
```

The isolated v0.7.2 source tree with the preceding OnePlus patches applied
accepted the patch with `git am`, passed `git diff --check`, and built all 46
selected simple-IPA/libcamera targets with GCC, Meson and Ninja using
`-Dwerror=true`. The regenerated pmaports integration patch applies cleanly to
base `875bddba6538818f2c3c9849e184f40688ad5140`; its current SHA-256 is
`144f69cbe3c4b37d44fe0e03fe32c777c25f99ca7d42170e60003cbf05a7ad51`.

This is the source portion of the r26/r13 candidate release. Clean AArch64
runtime and IPA packages were subsequently built, signed and placed in the
guarded five-package `camera-r26-r13` prerelease. They remain uninstalled and
hardware-unaccepted. A physical shutter/gain test is still required; the
phone's USB-NCM link has no usable SSH banner, so no device mutation was
attempted.

## Advanced Snapshot r13 AArch64 package checkpoint

Date: 2026-08-26. The reproducible pmaports overlay now carries the
compile-fixed Advanced Snapshot r13 recipe, pinned to source commit
`eef98bbb16a5af6cdb21150811a4ea33d6543daf`. The overlay applies cleanly to
pmaports base `875bddba6538818f2c3c9849e184f40688ad5140`; its current
SHA-256 is
`144f69cbe3c4b37d44fe0e03fe32c777c25f99ca7d42170e60003cbf05a7ad51`.

A pmbootstrap 3.11.1 edge AArch64/musl package build completed successfully.
The package test phase passed all 15 cross-compiled tests (6 application and 9
Aperture), and `advanced-snapshot`'s independent validator accepted both
signed APKs for architecture, expected contents, metadata, schemas, resource
namespace, language split and overlap with distro Snapshot:

```text
advanced-snapshot-0.1.0-r13.apk: 0c12ce8685afcadd1794e4a530f231d461647e41066965b307b2a43d5f121c81
advanced-snapshot-lang-0.1.0-r13.apk: a03b0a561e4355a4da506e29f0d8b7f16173da694155391e465a3dbfeaab1bd3
public-key: 31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6
```

The package pair is source/package validated and is included in the opt-in
`camera-r26-r13` prerelease, but is not installed or hardware-accepted. The
matching libcamera r26 packages are recorded in the following checkpoint. The
reference phone still has no usable SSH banner, ADB device or fastboot
transport, so live camera, display, modem, audio, location, NFC, Waydroid,
battery and rollback acceptance remain open.

## Libcamera r26 and PipeWire r7 AArch64 package checkpoint

Date: 2026-08-26. The reproducible pmaports overlay built the patched
`libcamera-99990.7.2-r26` runtime and IPA packages for edge AArch64/musl with
all 19 OnePlus/simple-IPA patch files present in the composed tree. The build
completed 351 Meson/Ninja targets; the manual shutter/gain and continuous-AF
changes were included. The matching PipeWire r7 and
`pipewire-spa-libcamera` packages were already built in the same package
workspace.

The six relevant package signatures verified with the local pmaports APK key:

```text
libcamera-99990.7.2-r26.apk: 9d7f18701c19db365e981d0e6e741ce87232ccb7f022b47ac525fc90aac60552
libcamera-ipa-99990.7.2-r26.apk: 1a2d6228ed4afe9ac5c90500caa92f7c7370799ebbe89c9770da747a615e18d3
pipewire-1.6.8-r7.apk: ac971786a81c05b116e1ce8266b1fb5e317b37c3cdc30c023c1ebaf10ce8f894
pipewire-spa-libcamera-1.6.8-r7.apk: cf96212aaaa9a98d16109408a1d8a2e6723222154c51a82ef97cee8a0f240898
advanced-snapshot-0.1.0-r13.apk: 0c12ce8685afcadd1794e4a530f231d461647e41066965b307b2a43d5f121c81
advanced-snapshot-lang-0.1.0-r13.apk: a03b0a561e4355a4da506e29f0d8b7f16173da694155391e465a3dbfeaab1bd3
```

Direct payload inspection confirmed AArch64 ELF objects for the libcamera
runtime, simple IPA module and Advanced Snapshot executable. This is a
source/package checkpoint only: the packages are available in the opt-in
`camera-r26-r13` prerelease, but no phone package was installed, and no live
preview, focus, exposure, display, modem or rollback result is claimed.

The signed offline bundle is published as the GitHub prerelease
`camera-r26-r13`. Its reproducibility anchors are:

```text
oneplus6t-camera-r26-r13-aarch64.tar.gz: eb87cbc9589bec7138a007d5708e94e1481a68077ca19f1daa3d6e00c302739f
SHA256SUMS: fddd44393a9bad6321c4e846a967f67741588d312d0809727b1353df05fdb60e
```

The bundle contains five signed candidate packages and five signed rollback
packages, including the r24/r11 runtime/UI baseline. It is intentionally
opt-in and must pass the native camera smoke test on the reference phone
before being treated as a supported generation.

## Advanced Snapshot r14 Software HDR source checkpoint

Date: 2026-08-26. The overlay recipe now pins Advanced Snapshot source commit
`af69a7151b8fcba1d0650fd911f42e340279e8d0` and recipe revision r14. The
immutable GitHub source archive SHA-512 is
`e5973d2b5e72d154e6243ded37d26b88328c50be66f5e83b7038794f41df6e0c6cfe4d6e890485b2cd2e6c83d1ecffe1343b09bcd9f815087c5fd99799d64e0a`.
The updated pmaports integration patch SHA-256 is
`3f71542ce57df687f25838715fb569f9ecc658c76f1bdd9d6ad3032437ac2ff8`.

The source adds an opt-in Software HDR switch and the packaged
`advanced-snapshot-hdr` helper. It captures three exposure-bracketed JPEGs,
merges non-clipped samples in linear light, atomically installs one output and
cleans temporary frames on every completion or abort path. It explicitly does
not claim vendor ISP tuning or motion alignment. The pinned GTK build passed
Meson, formatting, 8 application tests, 5 HDR-helper tests, 9 Aperture tests,
clippy with `--deny warnings` and staged installation checks. The clean signed
AArch64 r14 pair passed the independent package validator and is included in
the opt-in `camera-r26-r14` generation; no phone installation or image-quality
acceptance is claimed.

The r14 package hashes are:

```text
advanced-snapshot-0.1.0-r14.apk: 0df78733ec2fc3469dd11a4be274a0fb1bbbb9921dbf18601f99e6b0fa58b0ec
advanced-snapshot-lang-0.1.0-r14.apk: 25d01d10d69099c6c6d837a0cdd30c8724b3e831bf8fbbdf0730e36d75b4d98f
public-key: 31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6
```

The signed five-package candidate and five-package rollback bundle is
published as the GitHub prerelease `camera-r26-r14`. Its reproducibility
anchors are:

```text
oneplus6t-camera-r26-r14-aarch64.tar.gz: 5d278feb47feb55d57625a20fef793d2eebab7acab67140aa2ce700e8e3de3b1
SHA256SUMS: b36d9ec268e351aa168e790b05aa72a23ba518a7ba4b81b2b2ddc53707aa37a6
```

The bundle is source/package validated but remains opt-in: no phone package
was installed, and live preview, focus, exposure, HDR, video, display,
modem, audio, location, NFC, Waydroid, battery and rollback acceptance remain
open behind the unavailable phone transport.

## Live SMARTY cellular and Waydroid location lifecycle acceptance

Date: 2026-08-27. After inserting the SMARTY SIM, ModemManager dynamically
enumerated the Qualcomm modem, registered at home on 3 UK LTE, attached packet
service and connected the database-selected `mob.asm.net` profile. The default
bearer supplied a static IPv4 configuration and DNS servers. NetworkManager
installed the cellular default in its policy table, and four ICMP packets
forced through the QMAP bearer interface completed with zero loss. Wi-Fi kept
the lower-metric ordinary default while connected, as intended. SMARTY's
current help page independently lists `mob.asm.net` with blank credentials.

The modem exposes `gps-raw`, `gps-nmea`, `agps-msa` and `agps-msb`. Raw/NMEA
enabled successfully at one-second refresh. Six timed samples carried current
UTC but consistently reported RMC invalid, GGA quality zero and GSA mode one,
so no coordinate was forwarded. Both advertised assisted modes failed with
`Failed to receive operation mode indication`; this is retained as a lower
ModemManager/Qualcomm gap rather than hidden by a guessed location.

Live Waydroid testing found and fixed two integration errors: current Waydroid
requires the `shell --` option boundary, and Android requires the
`android:mock_location` app-op for the UID used by `waydroid shell`. The bridge
now preserves that app-op, timestamps fixes and restores it on exit. With the
service running, `dumpsys location` showed `fused provider [mock]` with null
last/mock location. Stopping the service restored the ordinary fused provider
and app-op `default`; starting it again cleanly recreated the bridge. The unit
is enabled as a child of `waydroid-container.service`, so it does not force the
container to consume battery when Waydroid is otherwise stopped.

No coordinate, modem identifier, phone number or SIM identifier from this run
is committed. A genuine outdoor fix, GeoClue acceptance and Android map-app
acceptance remain open.
