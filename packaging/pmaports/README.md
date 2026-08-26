# Reproducible OnePlus 6T camera packages

`0001-oneplus6t-camera-stack.patch` integrates the complete camera stack into
pmaports: five SDM845 kernel patches, sixteen libcamera patches, three tuning
files, one PipeWire control/state-transport patch, three Snapshot patches, the
separately named Advanced Snapshot aport, checksums and package revision bumps.
It contains no APK, boot image, firmware, vendor library, photograph or
device-specific identifier. The current patch carries the r11 Advanced Snapshot
source recipe and the libcamera r25 continuous-AF reference candidate; r24 and
the previously signed app generations remain available as rollback baselines.
The phone's accepted runtime baseline remains Advanced Snapshot r1 and
libcamera r24 until recovery and a fresh device check.

## Reviewed base and build

The integration patch cleanly applies to pmaports commit
`875bddba6538818f2c3c9849e184f40688ad5140`.
Its SHA-256 is
`df39e156c3eeb09f4493a2d3a7c46fc3f18264c83703c7d3256f9b3cfb49f9cf`.

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

- `linux-postmarketos-qcom-sdm845-7.1_rc1-r8`;
- `libcamera-99990.7.2-r25` and `libcamera-ipa-99990.7.2-r25` (AF reference
  candidate; r24 remains the installed rollback);
- `pipewire-spa-libcamera-1.6.8-r7`;
- `snapshot-50.0-r3` plus `snapshot-lang-50.0-r3`; and
- `advanced-snapshot-0.1.0-r11` plus
  `advanced-snapshot-lang-0.1.0-r11` (bounded rear-flash candidate; not yet installed).

The high revisions preserve ordering above the camera packages already used
during live diagnosis. They do not imply that many public releases.

## Reference artifacts

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk` | `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e` |
| `libcamera-99990.7.2-r24.apk` | `80b3d0e0f55c492783bb95f031d2464dcf3e201e94ce9ea4dbfe7bc1473ef7b9` |
| `libcamera-ipa-99990.7.2-r24.apk` | `12023c5e4fb52588d531c3d643fa16ba7a992ef4ae3cbd0d6de235d0efcf79b8` |
| `libcamera-99990.7.2-r25.apk` (AF reference candidate) | `ccdfaf820ba6362cfbb4dae3ded92eb9e18542afcdde1596eb8bed91e9e7323f` |
| `libcamera-ipa-99990.7.2-r25.apk` (AF reference candidate) | `11efa3eaa05e00e0921cbf081fb1b1fe8fdd356a4fc1244cbbb13d90fc14608a` |
| `pipewire-spa-libcamera-1.6.8-r7.apk` | `c6e2f3dc9f27b89dc2ebef448e4242bfa3f40ae2606c146b291e5caa85e612d1` |
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

## Current installation and rollback baseline

The reference phone currently runs:

- kernel package `7.1_rc1-r8`;
- `libcamera` and `libcamera-ipa` `99990.7.2-r24`;
- `pipewire-spa-libcamera` `1.6.8-r7`;
- Snapshot and Snapshot language data `50.0-r3`; and
- Advanced Snapshot and its language data `0.1.0-r1`.

The r7/r1 packages above are one coherent installed generation: r7 transports
generation-correlated `AfState`, while r1 waits for that result and never
reports control acceptance as optical success. Both rear cameras returned a
correlated `focused` result and survived the 60-second post-reset test; the
fixed-focus front completed 120 frames and rejected focus as unsupported. Keep
all three r6/r0 APKs as the immediate rollback and install or roll them back
together.

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
