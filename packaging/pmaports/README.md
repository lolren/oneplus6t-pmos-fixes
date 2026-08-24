# Reproducible OnePlus 6T camera packages

`0001-oneplus6t-camera-stack.patch` integrates the complete camera stack into
pmaports: five SDM845 kernel patches, fourteen libcamera patches, three tuning
files, one PipeWire control-transport patch, three Snapshot patches, checksums
and package revision bumps. It contains no APK, boot image, firmware, vendor
library, photograph or device-specific identifier.

## Reviewed base and build

The integration patch cleanly applies to pmaports commit
`875bddba6538818f2c3c9849e184f40688ad5140`.
Its SHA-256 is
`f063d147676f957580f425c430cc39407e60a4ec0edfa6dfb29d2f4788d5140a`.

```sh
git checkout 875bddba6538818f2c3c9849e184f40688ad5140
git apply --check --whitespace=nowarn /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
git apply --whitespace=nowarn /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch

pmbootstrap -p "$PWD" build --arch aarch64 libcamera
pmbootstrap -p "$PWD" build --arch aarch64 pipewire
pmbootstrap -p "$PWD" build --arch aarch64 snapshot
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

If pmaports has moved, rebase the individual source patches. Do not force a
rejected integration hunk. The reference builds used pmbootstrap 3.11.0 and
completed for aarch64.

## Package revisions

Applying the integration patch to the reviewed base produces:

- `linux-postmarketos-qcom-sdm845-7.1_rc1-r8`;
- `libcamera-99990.7.2-r22` and `libcamera-ipa-99990.7.2-r22`;
- `pipewire-spa-libcamera-1.6.8-r6`; and
- `snapshot-50.0-r3` plus `snapshot-lang-50.0-r3`.

The high revisions preserve ordering above the camera packages already used
during live diagnosis. They do not imply that many public releases.

## Reference artifacts

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk` | `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e` |
| `libcamera-99990.7.2-r22.apk` | `0900e38b7945778e1e0c9219db9ad5a1fc31bcc7a9a154aa4dd7830fc3519644` |
| `libcamera-ipa-99990.7.2-r22.apk` | `6e56cbd696d8575d19a9aedf54093421718470ee67c1597dcb261d4dce41c9e9` |
| `pipewire-spa-libcamera-1.6.8-r6.apk` | `658658c3b9df142a6462e3a73457b44a378d6820dba0c6b05a14d18f865635d4` |
| `snapshot-50.0-r3.apk` | `5a59c32a3d3ef451bc85b0f19cb8fce617aaa4c6baba83e3595ddb9892a324e7` |
| `snapshot-lang-50.0-r3.apk` | `8eb9fd567ce10c91afb00a98e10b0056d7adbd7683ab0514c217806512b0b108` |

Independent builds may differ because APK metadata and signing keys are local.
Verify source, package version, architecture and behavior as well as hashes.
The reference IMX519 module has matching `7.1.0-rc1-sdm845` vermagic and a
PKCS#7 SHA-512 signature from its kernel build key. The final kernel package
does not contain the discarded actuator-readiness or diagnostics experiments.

## Current installation and rollback baseline

The reference phone currently runs:

- kernel package `7.1_rc1-r8`;
- `libcamera` and `libcamera-ipa` `99990.7.2-r22`;
- `pipewire-spa-libcamera` `1.6.8-r6`; and
- Snapshot and Snapshot language data `50.0-r3`.

The exact prior userspace packages are the rollback baseline. Keep their APKs,
or verified version-matched rebuilds, before reproducing the upgrade. Do not
assume that an online repository will continue to carry old versions.

| Rollback package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r20.apk` | `63f72a082088085c04ec42975ffadb5aa386d66a024c54394a3b5180fc628764` |
| `libcamera-ipa-99990.7.2-r20.apk` | `4c61f6b27f6b9f843b32bb292d57056cf9bafe321dfdb7648acbf28a47f649a8` |
| `pipewire-spa-libcamera-1.6.8-r6.apk` (unchanged) | `658658c3b9df142a6462e3a73457b44a378d6820dba0c6b05a14d18f865635d4` |
| `snapshot-50.0-r2.apk` | `f096f4a566fe5801fce8b784759f83222eeeba15a36829bf10f129ab764d4cc6` |
| `snapshot-lang-50.0-r2.apk` | `a86902e92caee59ca42113ccda42b08813e9975185012389f17826f114dbdaec` |

## Installation boundary

The build commands above do not copy or install anything, update boot files or
reboot. The completed camera update was userspace-only and did not require a
reboot. Installing on another phone still requires root, a reviewed simulation
and an explicit decision by its owner.

Stage patched and rollback APKs in separate offline repositories. apk-tools 3
reads `APKINDEX.tar.gz` from the native `aarch64/` directory, but constructs the
download path from each package's declared architecture. Therefore put the four
aarch64 APKs in `aarch64/`, put `snapshot-lang` in `noarch/`, and include both
directories when generating the one native index. Pass the repository root to
apk, not its `aarch64/` subdirectory.

This layout was tested with apk-tools 3.0.7: `apk fetch --url` resolved
`snapshot-lang-50.0-r3.apk` under `/noarch/`, and the fetched file's SHA-256
matched the staged file. Placing the noarch APK only beside the native index
causes a late file lookup failure and can split the transaction.

```sh
mkdir -p patched/aarch64 patched/noarch rollback/aarch64 rollback/noarch
apk index --allow-untrusted -o patched/aarch64/APKINDEX.tar.gz \
  patched/aarch64/*.apk patched/noarch/*.apk
apk index --allow-untrusted -o rollback/aarch64/APKINDEX.tar.gz \
  rollback/aarch64/*.apk rollback/noarch/*.apk
```

From the directory containing `patched/`, simulate first:

```sh
apk upgrade --simulate --allow-untrusted --network=no \
  --interactive=no --repository "$PWD/patched" \
  libcamera libcamera-ipa pipewire-spa-libcamera snapshot snapshot-lang
```

Starting from the documented baseline, it must list exactly these
transitions and no removal:

```text
libcamera-ipa           99990.7.2-r20 -> 99990.7.2-r22
libcamera               99990.7.2-r20 -> 99990.7.2-r22
snapshot                 50.0-r2      -> 50.0-r3
snapshot-lang            50.0-r2      -> 50.0-r3
```

Only after reviewing that output and receiving approval may the same command
be run as root without `--simulate`. Record a SHA-256 of `/etc/apk/world`
before and after; the reference transaction left it unchanged. `--allow-untrusted`
is appropriate only for locally built packages whose source, version and hash
were independently verified.

Close all camera applications before the userspace transaction and reopen them
afterward. On a fresh installation that also needs kernel r8, handle the kernel
as a separate approved transaction: its release string is unchanged and its
package replaces modules in the running kernel's module path, so no camera may
be opened between that transaction and the approved reboot.

## Rollback

Simulate exact-version rollback against the isolated rollback repository:

```sh
apk add --simulate --allow-untrusted --network=no \
  --interactive=no --repository "$PWD/rollback" \
  'libcamera=99990.7.2-r20' \
  'libcamera-ipa=99990.7.2-r20' \
  'snapshot=50.0-r2' \
  'snapshot-lang=50.0-r2'
```

Require exactly four downgrades, no PipeWire change and no removals.
Exact-version `apk add`
temporarily pins those versions in `/etc/apk/world`; preserve a pre-test copy
and hash, then remove only the pins added by this command after verifying the
installed versions. Never replace the whole file with an unverified copy.

Never use `apk upgrade --available` with either partial repository. apk-tools
3 may reconcile the whole installation against that partial index and remove
unrelated packages.
