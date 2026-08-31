# Reproducible OnePlus 6T camera packages

`0001-oneplus6t-camera-stack.patch` integrates the complete camera stack into
pmaports: seven SDM845 kernel patches, twenty-one project libcamera patches,
three tuning files, two PipeWire control/state-transport patches, six Snapshot patches, the
separately named Advanced Snapshot aport, checksums and package revision bumps.
It contains no APK, boot image, firmware, vendor library, photograph or
device-specific identifier. The current patch carries the r34 Advanced Snapshot
source recipe and its verified AArch64 package pair, the libcamera r34 colour-
matrix/white-balance/manual-focus/tone/test-pattern generation and PipeWire r8 float-array
transport; r24, r25, r26, r28 and r33 plus
the previously signed app generations remain available as rollback baselines.
It also carries the Samsung panel brightness-serialization patch and bounded
Qualcomm Venus firmware-error recovery as kernel r10, with kernel r8 retained
as its rollback package. r10 is installed and booted on the reference phone;
brightness-specific acceptance remains separate from codec safety acceptance.
The exact signed repositories, manifest and key are published in the
[kernel-r8-r10 pre-release](https://github.com/lolren/oneplus6t-pmos-fixes/releases/tag/kernel-r8-r10).
The reference phone has r33/r8/r3 userspace and the visible Image Controls
Advanced Snapshot r34 build installed without reboot; the earlier r30 app,
r28/r7 lower stack and r0/r1 app packages remain rollback baselines.

The current source target is r34/r34/r8; the reference phone remains on the
last accepted r33/r8/r3 line until the new colour package is built and
installed. The current r33/r34/r8 evidence is:

- libcamera/IPA r33 with normalized rear `LensPosition`, `AwbEnable`, two-
  element `ColourGains` and nine-element `ColourCorrectionMatrix` controls;
- PipeWire SPA r8 with generic fixed-size float-array transport;
- libcamera/IPA r33 with sensor-specific profiles and the accepted conservative
  row-sum-preserving green-cast correction on all three sensors;
- the r34 source target with a moderate row-sum-preserving follow-up matrix;
- a verified IMX519 equal-channel sensor test pattern that remains neutral
  through the GPU processed path after AWB settles;
- Advanced Snapshot commit `0376f68c6808517fdc368d8e92ce67a0463ce960`;
- main APK SHA-256 `7f94c88bbc5d7ec300a7f2f1481dff7f882bd43480506fef18f79fdffa390c74`;
- language APK SHA-256 `6326708ca21e1dacd4e4264cf48358ccc59d8a99dc2f88be5d36cc46f19ef5de`;
- native main/secondary AF validation with 183/239 post-reset metrics and
  zero lens requests; and
- Waydroid manual-focus result deltas of 2.000 on both rear IDs plus
  terminal tap-focus results on both rear IDs.

The app package adds the visible Image Controls panel, standard Gamma,
automatic/manual white balance, a writable standard colour matrix and a per-
sensor calibration dialog. The dialog saves bounded exposure, red/blue gains,
matrix, tone/detail and optional manual-focus values under a stable sensor
identity. r34 adds named Sensor default, Neutral, Natural, Vivid and Custom
presets in a camera-page overlay drawer so the upper preview stays visible
while controls are changed; it does not provide Android's factory
  coefficients, lens shading or multi-frame ISP tuning. Saved-photo scene
  acceptance remains separate. The r34 still path reapplies rear focus after
  its preview-to-photo stream hand-off, so a focused preview no longer leaves
  the fresh high-resolution stream at an unrelated lens position.

## Reviewed base and build

The integration patch cleanly applies to pmaports commit
`875bddba6538818f2c3c9849e184f40688ad5140`.
Its current SHA-256 is
`dcfe71299dfd7dbd0c346dc13a6807fb2ce438f38b36480e784f698dbe51070a`.

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

If pmaports has moved, rebase the individual source patches. Do not force a
rejected integration hunk. The current reference build used pmbootstrap 3.11.1 and
completed for aarch64.

## Package revisions

Applying the integration patch to the reviewed base produces:

- `linux-postmarketos-qcom-sdm845-7.1_rc1-r10` (display brightness
  serialization plus bounded Venus firmware-error recovery; r8 remains the
  rollback package);
- `libcamera-99990.7.2-r34` and `libcamera-ipa-99990.7.2-r34` (writable colour
  matrix, white balance, manual-focus, stable-AF, conservative tone generation
  and downstream sensor-specific colour profiles; r24/r25/r26/r28/r29/r30/r31/r32 remain retained
  diagnostic and rollback candidates);
- `pipewire-spa-libcamera-1.6.8-r8` (autofocus state plus generic fixed-size
  float-array control transport; r7 remains retained for rollback);
- `snapshot-50.0-r6` plus `snapshot-lang-50.0-r6`; and
- `advanced-snapshot-0.1.0-r34` plus
  `advanced-snapshot-lang-0.1.0-r34` (handheld-aligned Software HDR,
  camera-page live-control drawer and colour presets,
  serialized camera teardown, rear manual-focus, tone-default, Gamma and
  white-balance/colour-matrix-aware per-sensor calibration build with a phone-
  width dialog and unobstructed zoom toolbar; an exact AArch64 APK pair was built in the isolated
  edge buildroot and installed on the reference phone without reboot); and
  the signed r11 pair remains the retained rollback baseline.

The high revisions preserve ordering above the camera packages already used
during live diagnosis. They do not imply that many public releases.

The r34 application recipe is pinned to Advanced Snapshot commit
`0376f68c6808517fdc368d8e92ce67a0463ce960`. Its GitHub source archive SHA-512
is
`8e0f698d342fead6b92e4cef5de2f266f717f23fd65dd287d9a520c0457433edb2387d32e6c007a5909db8773052c5720094648cabbdeee7126347bf508388ab`.
The pinned GTK/GStreamer source build passed after the GStreamer state-tuple
compatibility fix. The exact AArch64 pair was built and installed with the
local pmbootstrap signing key. The phone-width calibration dialog and toolbar
zoom placement passed visual acceptance; repository-key release publication
remains separate.

The Snapshot r6 candidate adds the asynchronous camerabin teardown barrier on
top of the earlier r3 package and r4 lifecycle guard, plus the GStreamer Rust
state-tuple compatibility fix. It is source-tested and included in the
integration patch. A clean isolated release build passes, but no r6 APK hash
is claimed until an AArch64 package build and phone acceptance are completed.
Keep the signed r3 packages as the rollback baseline.

The r34 libcamera revision and PipeWire r8 are source- and package-validated. Their
standalone patches and the full integration diff apply cleanly; the accepted
r33 AArch64 packages expose the normalized rear
`LensPosition` range plus standard automatic/manual white balance and writable
colour matrices on all three sensors, r33 exposes the verified sensor test
pattern for calibration, and r33 installs the documented conservative
green-corrected sensor profiles. The r34 source retains equal-channel grey
while applying the stronger moderate correction; its device installation and
live chart acceptance are still pending.
The correction is not a factory colour calibration claim. Keep the signed r24/r25/r26/r28/r29/r30/r31/r32/r33 and
PipeWire r7 APKs for rollback.

The complete opt-in userspace transition is described by
`data/camera-generation-r26-r15.psv`. Its five-package candidate updates the
r24 `libcamera`/IPA pair and the r11 Advanced Snapshot pair together, retains
PipeWire r7, and keeps the exact r24/r11 packages as rollback. The generation
manager verifies the candidate key before its offline simulation. It is not
the default generation until the phone's live camera and lifecycle checks
pass. The earlier r26/r14 and r26/r13 manifests remain available for exact
reproduction.

The r15 Software HDR helper is intentionally opt-in. It aligns bounded global
camera translation against the middle exposure, merges three bracketed JPEGs
in linear light and writes one result atomically. It does not compensate
independently moving subjects, rotation, parallax or non-rigid motion, and it
does not provide Android-vendor lens shading, calibrated colour or proprietary
ISP processing. Review the complete candidate with:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r26-r15 \
  --manifest data/camera-generation-r26-r15.psv \
  install
```

## Reference artifacts

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk` | `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e` |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk` (historical display candidate) | `6049f30fb9ed0b5576f309720bfd75ea4d8faded4eadf10fc887d3d0a0aeb957` |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r10.apk` (installed display/Venus safety generation) | `f5b3c8fa795b63718eebab9f2adbc0bee7545d2b147d5a0f3c1ae63c8176597e` |
| `libcamera-99990.7.2-r24.apk` | `80b3d0e0f55c492783bb95f031d2464dcf3e201e94ce9ea4dbfe7bc1473ef7b9` |
| `libcamera-ipa-99990.7.2-r24.apk` | `12023c5e4fb52588d531c3d643fa16ba7a992ef4ae3cbd0d6de235d0efcf79b8` |
| `libcamera-99990.7.2-r25.apk` (AF reference candidate) | `ccdfaf820ba6362cfbb4dae3ded92eb9e18542afcdde1596eb8bed91e9e7323f` |
| `libcamera-ipa-99990.7.2-r25.apk` (AF reference candidate) | `11efa3eaa05e00e0921cbf081fb1b1fe8fdd356a4fc1244cbbb13d90fc14608a` |
| `libcamera-99990.7.2-r26.apk` (manual-exposure candidate) | `9d7f18701c19db365e981d0e6e741ce87232ccb7f022b47ac525fc90aac60552` |
| `libcamera-ipa-99990.7.2-r26.apk` (manual-exposure candidate) | `1a2d6228ed4afe9ac5c90500caa92f7c7370799ebbe89c9770da747a615e18d3` |
| `libcamera-99990.7.2-r28.apk` (installed manual-focus/tone generation) | `f2715804c65132fa4f547a11472f5afe722aa3a3afafecefaed940269509f9d1` |
| `libcamera-ipa-99990.7.2-r28.apk` (installed manual-focus/tone generation) | `619f9de2d4eabefb24437847821aa858c3c369c2b8d61af8a4a4b887b4a0669d` |
| `libcamera-99990.7.2-r29.apk` (installed white-balance generation) | `eec79f739f4b6d702f02a4f0b977c9d67a22a0280b46bdc0a813abf782f2389d` |
| `libcamera-ipa-99990.7.2-r29.apk` (installed white-balance generation) | `ab98208181a36165be34f2547c3239366bf6dd6e64eaf11b320ff02f08e25b0b` |
| `libcamera-99990.7.2-r30.apk` (installed colour-matrix generation) | `02617ef50c66d0e6c19d78a8dafe18491ac6b5131f7912282ec90d18ea5dc39f` |
| `libcamera-ipa-99990.7.2-r30.apk` (installed colour-matrix generation) | `d6b4ff5875fbd465c73c42323dc4876e92eea7abece04aa164476ee2ed30e1d2` |
| `libcamera-99990.7.2-r31.apk` (installed sensor-colour generation) | `573b24e1249e2e2a91731dfd5fe57949e966e48ca2f3a2a4e5ff128c71dc4038` |
| `libcamera-ipa-99990.7.2-r31.apk` (installed sensor-colour generation) | `f04b0ab0c147129484d6ae8c57bac6c4f49fa35513f581d2b2ab0214dffeafaf` |
| `libcamera-99990.7.2-r32.apk` (sensor test-pattern diagnostic) | `b2d0f0d71335df67a02150e4333110736af7027905d57d6b56cbd5240b4bdd2` |
| `libcamera-ipa-99990.7.2-r32.apk` (sensor test-pattern diagnostic) | `b9fe95d95b751329d754ba05b78f8a71af625362523ad697dd1609ebcd070854` |
| `libcamera-99990.7.2-r33.apk` (green-cast correction plus test pattern) | `76808314599b548a86c2924aaea82b98ce0a913a38967acfd32cd95b54684f6d` |
| `libcamera-ipa-99990.7.2-r33.apk` (green-cast correction plus test pattern) | `b54c2ada1f1e2bd833c385247ee796cbd58a40077d7f74646e5d7b5e36c9c89e` |
| `libcamera-99990.7.2-r34.apk` (moderate green-cast follow-up; built, not yet device-accepted) | `7e241928daaab4ed285160b1ea6d89d758f92783851093ec406d7c3590b450b3` |
| `libcamera-ipa-99990.7.2-r34.apk` (moderate green-cast follow-up; built, not yet device-accepted) | `e4b4d96b1f3f391eb63bb72361380652594e956051ed0427aebd69eb9e444fed` |
| `pipewire-spa-libcamera-1.6.8-r7.apk` | `c6e2f3dc9f27b89dc2ebef448e4242bfa3f40ae2606c146b291e5caa85e612d1` |
| `pipewire-spa-libcamera-1.6.8-r8.apk` (installed float-array transport) | `ac9a89ca85e06b17f74ed8968e745f28bf77a4bf94c0fc318012e4d1d52b9d18` |
| `snapshot-50.0-r3.apk` | `5a59c32a3d3ef451bc85b0f19cb8fce617aaa4c6baba83e3595ddb9892a324e7` |
| `snapshot-lang-50.0-r3.apk` | `8eb9fd567ce10c91afb00a98e10b0056d7adbd7683ab0514c217806512b0b108` |
| `advanced-snapshot-0.1.0-r2.apk` (previous accepted app build) | `73d8fd40640a5a73521cc376418c38fae6413abcd450c18193d9568b236a9d18` |
| `advanced-snapshot-lang-0.1.0-r2.apk` (previous accepted app build) | `82cf5d353b7c5fd68ba1ba795a4a1f51ae0ae214d6e88d90f452d5025bd8f37a` |
| `advanced-snapshot-0.1.0-r7.apk` (current source candidate) | `35179b51fa6180688c0f4a62f3fe2a82b4c031733a4dc66d8e7229b5d2c1c6d9` |
| `advanced-snapshot-lang-0.1.0-r7.apk` (current source candidate) | `1b1916aca508c557f4b035d5fa5f161809afbe2ab91874d85962ae31152ffee9` |
| `advanced-snapshot-0.1.0-r8.apk` (capture-safety candidate) | `becc4bc1a734af22b28b7dde7f47c792af6386a93c3b24f2b53bdb47bebc70dd` |
| `advanced-snapshot-lang-0.1.0-r8.apk` (capture-safety candidate) | `f615e75c29579bf877e611a10178021936ab5f63388e9d0f9d041d39b0e56c77` |
| `advanced-snapshot-0.1.0-r9.apk` (save-feedback candidate) | `9583bfe6e286cbcb6bcda397d817554d09726f9cf29ad505a901803c3d35a555` |
| `advanced-snapshot-lang-0.1.0-r9.apk` (save-feedback candidate) | `59c60305a08d352ddc3fc70c881939e54c05c8e329aa6d6ba1339b5ecfdb6bfa` |
| `advanced-snapshot-0.1.0-r11.apk` (bounded rear-flash candidate) | `f4dafe29a4682df10b4649fee3110dac419c8179098e0a9762f48a2251cf7c1b` |
| `advanced-snapshot-lang-0.1.0-r11.apk` (bounded rear-flash candidate) | `40a9a822421d5640ce14f1046006bbb5b92b022862d977de0d7d14cf30f2c95a` |
| `advanced-snapshot-0.1.0-r13.apk` (manual-exposure compile-fixed candidate) | `0c12ce8685afcadd1794e4a530f231d461647e41066965b307b2a43d5f121c81` |
| `advanced-snapshot-lang-0.1.0-r13.apk` (manual-exposure compile-fixed candidate) | `a03b0a561e4355a4da506e29f0d8b7f16173da694155391e465a3dbfeaab1bd3` |
| `advanced-snapshot-0.1.0-r14.apk` (Software HDR candidate) | `0df78733ec2fc3469dd11a4be274a0fb1bbbb9921dbf18601f99e6b0fa58b0ec` |
| `advanced-snapshot-lang-0.1.0-r14.apk` (Software HDR candidate) | `25d01d10d69099c6c6d837a0cdd30c8724b3e831bf8fbbdf0730e36d75b4d98f` |
| `advanced-snapshot-0.1.0-r15.apk` (handheld-HDR-alignment candidate) | `16581bcf5c96aa74c522c4f51bbd5cb03711a3e41abd02f00a6d9eec7cf61705` |
| `advanced-snapshot-lang-0.1.0-r15.apk` (handheld-HDR-alignment candidate) | `dec0ec0c229848a0e157e2eba49ab9e74d30423e69ae76bbd73773eea97b61d2` |
| `advanced-snapshot-0.1.0_p20260829215222-r16.apk` (installed manual-focus build) | `46cc19ac583d3ba84fcd400b3e1be4506f583eee404cce11dc8312acea85408d` |
| `advanced-snapshot-lang-0.1.0_p20260829215222-r16.apk` (installed manual-focus build) | `3da06127a14216a2463b4454ade32c5d239f03c53cd4d501ac0713e3a1084f9e` |
| `advanced-snapshot-0.1.0_p20260829225220-r16.apk` (installed visible Controls build) | `677c09016eb673ee1f6bc033435073871da551aaadfe7291f09ea7b81c57d10e` |
| `advanced-snapshot-lang-0.1.0_p20260829225220-r16.apk` (installed visible Controls build) | `968f885fdd01ee6661bf63f0d58d969c290cf9a09865c733f841a1101a22c4af` |
| `advanced-snapshot-0.1.0-r30.apk` (installed white-balance calibration build) | `93205595cbd6c168c5179d8f57d7b2b036d8606ccca12d3101ae46ed7ccecb51` |
| `advanced-snapshot-lang-0.1.0-r30.apk` (installed white-balance calibration build) | `b98c7646f84ffc78f5b1c155f5a72cf7b7cc1ede5fb358fc74d365cb9122212e` |
| `advanced-snapshot-0.1.0-r32.apk` (historical colour calibration/mobile-layout build) | `269f68cb9d2fc7061a7277f21f70c87641d2a20a7206a090bbbbbd279a09ce5b` |
| `advanced-snapshot-lang-0.1.0-r32.apk` (historical colour calibration/mobile-layout build) | `8bc79a14ed890dd429188cb7b173cc9d13c61572c92faea4b4f24de66501e377` |

Independent builds may differ because APK metadata and signing keys are local.
Verify source, package version, architecture and behavior as well as hashes.
The reference IMX519 module has matching `7.1.0-rc1-sdm845` vermagic and a
PKCS#7 SHA-512 signature from its kernel build key. The final kernel package
does not contain the discarded actuator-readiness or diagnostics experiments.

The previous r7 source candidate is pinned to Advanced Snapshot commit
`0df3acc7626a5d5db195c58536ab649e16b83cd3`. Its GitHub source archive has
SHA-512
`194a5e16bf66852edcc34de31d9c94d01eeb191f453e8576edfcc10525a34ab904a61e5b637072f2f5d1f25326e72c16db0305e187309b2ae1072b6ade37a9c3`.
It adds the asynchronous live-sink preview candidate (`sync=false`, `qos=true`)
on top of the previously accepted one-buffer preview queue. The corresponding
r7 APK was not installed or claimed as accepted because the reference phone's
Waydroid rootfs/I/O recovery gate is still closed; build the package in a clean
aarch64 buildroot and validate it on the phone before replacing the r1 baseline.

The r8 capture-safety candidate is pinned to Advanced Snapshot commit
`d1e4831ad809270e3f3e0db1f41dda5f2e3d96a3`. Its GitHub source archive has
SHA-512
`d1371e84da7fc4aa061ce96f1e77faf63e61ed756442830b1f376c729d3f3f7510fad1b6707e7d95f36c975c4984921a7bb041bd00255ebb38eaa7e560feee12`.
It rejects missing, non-local, empty or non-regular capture outputs before they
reach the gallery, makes zoom clamping safe when a camera reports unusable
limits, and treats unknown orientation values as a harmless no-op. The clean
aarch64 build passed 6 application tests and 9 Aperture tests; the package
validator passed signatures, AArch64 ELF, metadata, resource namespace and
language-split checks. It is published as the opt-in `camera-r7-r6` generation
with r7 as the exact rollback. It has not been installed or hardware-accepted.

The r9 capture-save feedback candidate is pinned to Advanced Snapshot commit
`ec9f03db6177b8c0ee5fda826668fbbce59d9423`. Its GitHub source archive has
SHA-512
`8e0c20384443b06251affc932ccca0e93929cc31a2cadc473e0fb6606725801ba7775711f1ad926a162bb23c0c5b5e850d139ae81aa519447ee759a3099b5125`.
It reports a visible save-error toast when the capture pipeline produces no
usable file instead of silently returning to the preview. Its signed aarch64
APK hashes are `9583bfe6e286cbcb6bcda397d817554d09726f9cf29ad505a901803c3d35a555`
for the main package and
`59c60305a08d352ddc3fc70c881939e54c05c8e329aa6d6ba1339b5ecfdb6bfa` for the
language package. Both passed the cross-build and package validator.

The r10 adjustment-serialization candidate is pinned to Advanced Snapshot
commit `2a9763b8f42c1bb755a507de1cc49ed3c8f09a77`. Its GitHub source archive
has SHA-512
`ebb1e7818dd9777a5b794ba0667cf449957949a0f3d6e4cb014f12f85538b2d9b9dfad9fe5ec700e2c3accbd6e555cfc457f7cde78c22a03ef93b060bfc1a5b5`.
The candidate invalidates stale adjustment helpers on superseding slider
requests and page or camera teardown. Its r10 APK hashes are
`f832c5b3ae4e96969fccba8c8f563e7ff8a7372e3fef7d9b32dc7d5fb9828eb9` and
`2756823e3cb3ad68575bbe96d88a20cc99ecdc7440c405ba143baf43fdf99fb9`.
The signed `camera-r7-r10` stage keeps PipeWire r7 unchanged and retains the
r9 app pair for rollback. It is source/package validated but not installed or
hardware-accepted.

The r11 bounded rear-flash candidate is pinned to Advanced Snapshot commit
`0512a75b1419db5621e4e65c7c4ea5b3446aeeac`. Its GitHub source archive has
SHA-512
`84b4849ebd8b46e8473a1cea2c8197cb54a9fed54435cac44528c4575b285b3c1f8341b52e9639d7da1eb5b928eee1568efb525a48ec36462feab96e4e79bb37`.
The clean pmbootstrap edge AArch64/musl build passed all 15 cross-compiled
tests and the independent package validator. The signed package hashes are
recorded above. The matching `camera-r7-r11` stage keeps PipeWire r7 and
retains the r10 app pair for rollback; it remains uninstalled and
unhardware-tested until the phone transport is restored.

The libcamera r25 candidate is built from the same v0.7.2 source and the
updated generic AF patch. It requires three consecutive high-contrast monitor
windows before raising the IMX376/IMX519 continuous-focus reference and moves
only 20% toward the least extreme candidate window. The clean AArch64 build
produced the two signed packages above; pmbootstrap also reported pre-existing
untrusted staged candidate APKs while refreshing its local index, so the
artifact hashes—not that index warning—are the package evidence. The candidate
is not installed or hardware-accepted. Keep the r24 APK pair for rollback.

The display r9 candidate is built from the pinned sdm845 source with
`0006-drm-panel-samsung-s6e3fc2x01-serialize-brightness.patch`. It serializes
the panel brightness DCS transaction and restores the original DSI mode flags
on errors. Its signed APK SHA-512 is
`eede250d35ef4ed27309e87d2251c0c73388bbc020ffef493ba9c469bf940acd4531c1e8b5bd2765913e758b906fb1d5277d921b19e5c2eaa30bfe64b470c038`.
The signed r8/r9 offline stage is published as the `display-r8-r9`
prerelease. It remains uninstalled and unhardware-tested until the phone's
transport is recovered; use `pmos-manage-display-kernel` for its
simulation-first transition and rollback.

A clean local rebuild on 2026-08-26, using the checksum-verified Linux source
archive and the same pinned integration patch, produced a newly signed APK
with SHA-256
`488a11f8a473a869a6caa1f5d20c179088018bc531be0848db40f43cc9093efe` and
SHA-512
`f63bcf8309bf012a667075c2128c60a6b68588deeb23debfa21e21aa8b96127cac967365fde0530b2a4311dbd4775d9050e7fe597bbd9a36d7818f66f9a14769`.
The release manifest intentionally remains pinned to the published artifact;
use the release archive for the documented installer flow.

## Current installation and rollback baseline

The reference phone's current development camera stack runs:

- kernel package `7.1_rc1-r10`;
- `libcamera` and `libcamera-ipa` `99990.7.2-r28`;
- `pipewire-spa-libcamera` `1.6.8-r7`;
- Snapshot and Snapshot language data `50.0-r3`; and
- Advanced Snapshot and its language data `0.1.0-r24`.

The r28/r24 packages above are the current coherent generation: r7 transports
generation-correlated `AfState`, r28 adds the normalized rear `LensPosition`
contract, and r24 waits for correlated results while exposing Gamma, per-sensor
calibration, manual focus and Reset-to-continuous-AF in the UI. Both rear
cameras returned a correlated `focused` result and survived the 60-second
post-reset test; the fixed-focus front completed 120 frames and rejected focus
as unsupported. Keep the exact lower-stack and app package files as rollback
and install or roll them back together.

The exact r24 libcamera packages are the preferred rollback for the r25
autofocus-reference update. The exact r23 pair and older complete r20/r6/r2 set remain useful when rolling
back the earlier Snapshot and PipeWire work. Keep local APKs, or verified
version-matched rebuilds, before reproducing either transition. Do not assume
that an online repository will continue to carry old versions.

| Immediate r24 rollback package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r23.apk` | `45f6bd97df378aa8820f4651675f1b11b5d55f1294fe8116d6f01265c832687d` |
| `libcamera-ipa-99990.7.2-r23.apk` | `63dcf5ef5b1fdc29652b5c2e5e3e729681719c42f06c1183e010e71d94067bf2` |

| Rollback package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r20.apk` | `63f72a082088085c04ec42975ffadb5aa386d66a024c54394a3b5180fc628764` |
| `libcamera-ipa-99990.7.2-r20.apk` | `4c61f6b27f6b9f843b32bb292d57056cf9bafe321dfdb7648acbf28a47f649a8` |
| `pipewire-spa-libcamera-1.6.8-r6.apk` (unchanged) | `658658c3b9df142a6462e3a73457b44a378d6820dba0c6b05a14d18f865635d4` |
| `snapshot-50.0-r2.apk` | `f096f4a566fe5801fce8b784759f83222eeeba15a36829bf10f129ab764d4cc6` |
| `snapshot-lang-50.0-r2.apk` | `a86902e92caee59ca42113ccda42b08813e9975185012389f17826f114dbdaec` |

| Immediate r7/r1 rollback package | SHA-256 |
| --- | --- |
| `pipewire-spa-libcamera-1.6.8-r6.apk` | `658658c3b9df142a6462e3a73457b44a378d6820dba0c6b05a14d18f865635d4` |
| `advanced-snapshot-0.1.0-r0.apk` | `f76372802060de0722cddec238da63ec97dfeae7faf6dc29058bd061fed63bad` |
| `advanced-snapshot-lang-0.1.0-r0.apk` | `13c9078e499a22ea292f9024b443dbd37d9c9181fb4cc18dbb810665cfd1cd43` |

| Historical r7/r2 UI candidate or immediate r7/r1 rollback package | SHA-256 |
| --- | --- |
| `pipewire-spa-libcamera-1.6.8-r7.apk` (both sides) | `c6e2f3dc9f27b89dc2ebef448e4242bfa3f40ae2606c146b291e5caa85e612d1` |
| `advanced-snapshot-0.1.0-r2.apk` | `73d8fd40640a5a73521cc376418c38fae6413abcd450c18193d9568b236a9d18` |
| `advanced-snapshot-lang-0.1.0-r2.apk` | `82cf5d353b7c5fd68ba1ba795a4a1f51ae0ae214d6e88d90f452d5025bd8f37a` |
| `advanced-snapshot-0.1.0-r1.apk` (rollback) | `1e19e6d3bfa990d9ae4440fcc0364383e7cfc36de835689d2a2d5d1748368795` |
| `advanced-snapshot-lang-0.1.0-r1.apk` (rollback) | `7329bc3133cacd288e1f95e9cb93e69f71acc986b0bf1a875e8e4cd0469a47c8` |

## Installation boundary

The build commands above do not copy or install anything, update boot files or
reboot. The r7/r5 generation is userspace-only and needs no reboot. Installing
on another phone still requires root, a reviewed simulation and an explicit
decision by its owner.

The preferred interface is the simulation-first generation manager:

```sh
./scripts/manage-camera-generation \
  --stage /absolute/path/to/camera-r7-r5 \
  install
```

It consumes the immutable manifest in `data/camera-generation-r7-r5.psv`,
checks the bundled public-key hash, repository-index signatures and all six
package hashes/signatures, then
requires exactly the two app transitions and no PipeWire operation. Add
`--apply` only after reviewing the evidence. `rollback` selects the guarded
reverse transition. See
`docs/CAMERA_GENERATIONS.md` for its complete refusal and health-check policy.

To reproduce the completed r6/r0-to-r7/r1 update instead, pass
`--manifest data/camera-generation-r7-r1.psv` and stage the three candidate
APKs and three rollback APKs in separate offline repositories. apk-tools 3 reads
`APKINDEX.tar.gz` from the native `aarch64/` directory. Pass the repository
root to apk, not its `aarch64/` subdirectory.

Put `advanced-snapshot-lang` in `noarch/` and include it while generating the
native index. This mixed layout was tested with apk-tools 3.0.7; placing the
noarch APK beside the native index causes a late lookup failure and can split
a larger transaction.

```sh
mkdir -p candidate/aarch64 candidate/noarch rollback/aarch64 rollback/noarch
apk index --allow-untrusted -o candidate/aarch64/APKINDEX.tar.gz \
  candidate/aarch64/*.apk candidate/noarch/*.apk
apk index --allow-untrusted -o rollback/aarch64/APKINDEX.tar.gz \
  rollback/aarch64/*.apk rollback/noarch/*.apk
```

The original r0 app packages were installed from local files, so apk-tools 3
records identity constraints for them in `/etc/apk/world`. A package-name-only
`apk upgrade` can update PipeWire while silently retaining both r0 app
packages. Supply the two candidate app files explicitly and let their r7
dependency resolve from the candidate repository:

```sh
stage=$PWD
sudo apk add --simulate --upgrade --allow-untrusted --network=no \
  --interactive=no --repository "$stage/candidate" \
  "$stage/candidate/aarch64/advanced-snapshot-0.1.0-r1.apk" \
  "$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r1.apk"
```

Starting from the documented baseline, it must list exactly these
transitions and no removal:

```text
pipewire-spa-libcamera  1.6.8-r6 -> 1.6.8-r7
advanced-snapshot       0.1.0-r0 -> 0.1.0-r1
advanced-snapshot-lang  0.1.0-r0 -> 0.1.0-r1
```

Only after reviewing that output may the same command be run without
`--simulate`. Close camera applications and stop PipeWire/WirePlumber for the
short package transaction; start them and restart the desktop portal
afterward. On the reference phone the portal had retained a dead PipeWire
connection and recovered cleanly when restarted:

```sh
systemctl --user stop xdg-desktop-portal.service \
  xdg-desktop-portal-wlr.service
systemctl --user stop wireplumber.service pipewire.service pipewire.socket
# Run the accepted apk command above without --simulate.
systemctl --user start pipewire.socket pipewire.service wireplumber.service
systemctl --user reset-failed xdg-desktop-portal.service \
  xdg-desktop-portal-wlr.service
systemctl --user start xdg-desktop-portal-wlr.service \
  xdg-desktop-portal.service
```

Record `/etc/apk/world` before and after. The reference hash changed from
`e91dd5dc4a85594da5e28d11c014f6fefaf3b16adc6329f7e1000685de84b32e`
to
`d032cb41e42bda904382159b10198e5c2dd9b73cda58d3f0060993756388e276`.
The diff contained exactly the two expected r0-to-r1 Advanced Snapshot
identity-line replacements and no PipeWire entry or unrelated change. A
different verified build has different identity values, so review the diff
rather than copying these hashes. `--allow-untrusted` is appropriate only for
locally built packages whose source, version and hashes were independently
verified.

Close all camera applications before the userspace transaction and reopen them
afterward. On a fresh installation that also needs kernel r8, handle the kernel
as a separate approved transaction: its release string is unchanged and its
package replaces modules in the running kernel's module path, so no camera may
be opened between that transaction and the approved reboot.

## Rollback

Simulate the exact local-file r7/r1 rollback against the isolated rollback
repository:

```sh
stage=$PWD
sudo apk add --simulate --allow-untrusted --network=no \
  --interactive=no --repository "$stage/rollback" \
  "$stage/rollback/aarch64/pipewire-spa-libcamera-1.6.8-r6.apk" \
  "$stage/rollback/aarch64/advanced-snapshot-0.1.0-r0.apk" \
  "$stage/rollback/noarch/advanced-snapshot-lang-0.1.0-r0.apk"
```

Require exactly three downgrades, no libcamera or Snapshot change and no
removals. Then use the same service boundary as installation and run the same
command without `--simulate`.

Supplying the PipeWire APK temporarily adds it as a local identity constraint
even though the normal installation is dependency-owned. Verify its reverse
dependencies and simulate removal of only that world constraint:

```sh
apk info -r pipewire-spa-libcamera
sudo apk del --simulate pipewire-spa-libcamera
```

On the documented Phosh baseline the simulation must say the package is not
removed because `postmarketos-ui-phosh`, Advanced Snapshot and Snapshot retain
it. Only then run `sudo apk del pipewire-spa-libcamera`, and verify that
`apk list --installed pipewire-spa-libcamera` still reports r6. In an isolated
copy of the live apk database this returned the world file byte-for-byte to the
pre-update hash while retaining r6/r0. The downgrade solver and copied-database
transaction passed; a live rollback has deliberately not been performed.
Never replace the whole world file with an unverified copy.

Never use `apk upgrade --available` with either partial repository. apk-tools
3 may reconcile the whole installation against that partial index and remove
unrelated packages.
