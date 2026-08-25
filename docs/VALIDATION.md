# Validation record

All values below are sanitized. No IMEI, IMSI, ICCID, telephone number, account
credential, SSH key or device-unique serial is recorded.

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
Generated JPEGs remain private. Waydroid was returned to its prior stopped
state; the complete r23 overlay backup remains available for rollback.

## r7/r1 truthful autofocus package checkpoint

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

At this checkpoint the phone still runs r6/r0. Its `/etc/apk/world` SHA-256 is
`e91dd5dc4a85594da5e28d11c014f6fefaf3b16adc6329f7e1000685de84b32e`,
PipeWire and WirePlumber are active, Waydroid is stopped and no camera client
is active. The three-package simulation and all-sensor result test are the
remaining gates before replacing this rollback baseline.

## Remaining validation

A normal reboot test has not yet been performed for this repository revision.
NetworkManager profile persistence and autoconnect were verified with a manual
down/up cycle; boot-time reconnection must be recorded separately after an
explicitly approved reboot.

The r24/r6/r3 native userspace stack and r24 Waydroid overlay are installed and
required no phone reboot. Exact r23 libcamera and older r20/r6/r2 rollback APKs
remain staged in separate user-owned offline repositories.
An unlocked Snapshot touchscreen tap, focus indicator, saved full-resolution
photo, video, flash expectations, screen-off/on, suspend/resume and an actual
exact-version rollback test remain to be recorded. Android-level HDR, temporal
denoise, calibrated CCM/lens shading and computational fusion remain
unimplemented and are not represented as completed work. The Snapshot GUI
remains below the requested Android-camera control level and is the next camera
workstream. Waydroid needs
broader third-party camera-app, Play Store and lifecycle testing.
