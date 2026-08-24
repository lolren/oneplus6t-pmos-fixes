# Reproducible OnePlus 6T camera packages

`0001-oneplus6t-camera-stack.patch` integrates the complete camera stack into
pmaports: five SDM845 kernel patches, thirteen libcamera patches, three tuning
files, one PipeWire control-transport patch, two Snapshot patches, checksums and
package revision bumps. It contains no APK, boot image, firmware, vendor
library, photograph or device-specific identifier.

## Reviewed base and build

The integration patch cleanly applies to pmaports commit
`875bddba6538818f2c3c9849e184f40688ad5140`.
Its SHA-256 is
`6f16cff434f89ce319a23ed9a832737511e57ff42b58c06cdfb56175abcbe6ae`.

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
- `libcamera-99990.7.2-r20` and `libcamera-ipa-99990.7.2-r20`;
- `pipewire-spa-libcamera-1.6.8-r6`; and
- `snapshot-50.0-r2` plus `snapshot-lang-50.0-r2`.

The high revisions preserve ordering above the camera packages already used
during live diagnosis. They do not imply twenty public releases.

## Reference artifacts

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk` | `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e` |
| `libcamera-99990.7.2-r20.apk` | `63f72a082088085c04ec42975ffadb5aa386d66a024c54394a3b5180fc628764` |
| `libcamera-ipa-99990.7.2-r20.apk` | `4c61f6b27f6b9f843b32bb292d57056cf9bafe321dfdb7648acbf28a47f649a8` |
| `pipewire-spa-libcamera-1.6.8-r6.apk` | `658658c3b9df142a6462e3a73457b44a378d6820dba0c6b05a14d18f865635d4` |
| `snapshot-50.0-r2.apk` | `f096f4a566fe5801fce8b784759f83222eeeba15a36829bf10f129ab764d4cc6` |
| `snapshot-lang-50.0-r2.apk` | `a86902e92caee59ca42113ccda42b08813e9975185012389f17826f114dbdaec` |

Independent builds may differ because APK metadata and signing keys are local.
Verify source, package version, architecture and behavior as well as hashes.
The reference IMX519 module has matching `7.1.0-rc1-sdm845` vermagic and a
PKCS#7 SHA-512 signature from its kernel build key. The final kernel package
does not contain the discarded actuator-readiness or diagnostics experiments.

## Current installation and rollback baseline

The reference phone currently runs:

- kernel package `7.1_rc1-r8`;
- `libcamera` and `libcamera-ipa` `99990.7.2-r20`;
- `pipewire-spa-libcamera` `1.6.8-r6`; and
- Snapshot and Snapshot language data `50.0-r2`.

The exact prior userspace packages are the rollback baseline. Keep their APKs,
or verified version-matched rebuilds, before reproducing the upgrade. Do not
assume that an online repository will continue to carry old versions.

| Rollback package | SHA-256 |
| --- | --- |
| `libcamera-99990.7.2-r19.apk` | `073eb1f4b6d26d5573847724b13d2fe9ce79d4b578fa0a4e7097b1a108c79c91` |
| `libcamera-ipa-99990.7.2-r19.apk` | `fb9b5040714462c06750a28916c3ced706cd254ac502974c446b48a1325b2a0b` |
| `pipewire-spa-libcamera-1.6.8-r5.apk` | `49e9e2607cf8ef47d1a26fb5c05b283748b586a7950892803b9dd8e7cbc4e931` |
| `snapshot-50.0-r1.apk` | `cea8e0f03101ddf18364acae689d4cc1f4291db358718dd59b475485aaf7067d` |
| `snapshot-lang-50.0-r1.apk` | `1858d892e35d53b1ebdbeb37f6686f3469079671237a32ddc1abd76aa687ece7` |

## Installation boundary

The build commands above do not copy or install anything, update boot files or
reboot. The completed camera update was userspace-only and did not require a
reboot. Installing on another phone still requires root, a reviewed simulation
and an explicit decision by its owner.

Stage patched and rollback APKs in separate offline repositories. Put all five
APKs, including the noarch language package, in each repository's `aarch64/`
directory before generating `APKINDEX.tar.gz`. Omitting the noarch package from
that index turns an otherwise atomic upgrade into a partial transaction.

```sh
apk index -o patched/aarch64/APKINDEX.tar.gz patched/aarch64/*.apk
apk index -o rollback/aarch64/APKINDEX.tar.gz rollback/aarch64/*.apk
```

From the directory containing `patched/`, simulate first:

```sh
apk upgrade --simulate --allow-untrusted --network=no \
  --repositories-file /dev/null --repository "$PWD/patched/aarch64" \
  libcamera libcamera-ipa pipewire-spa-libcamera snapshot snapshot-lang
```

Starting from the documented baseline, it must list exactly these
transitions and no removal:

```text
libcamera-ipa           99990.7.2-r19 -> 99990.7.2-r20
libcamera               99990.7.2-r19 -> 99990.7.2-r20
pipewire-spa-libcamera   1.6.8-r5     -> 1.6.8-r6
snapshot                 50.0-r1      -> 50.0-r2
snapshot-lang            50.0-r1      -> 50.0-r2
```

Only after reviewing that output and receiving approval may the same command
be run as root without `--simulate`.

Close all camera applications before the userspace transaction and reopen them
afterward. On a fresh installation that also needs kernel r8, handle the kernel
as a separate approved transaction: its release string is unchanged and its
package replaces modules in the running kernel's module path, so no camera may
be opened between that transaction and the approved reboot.

## Rollback

Simulate exact-version rollback against the isolated rollback repository:

```sh
apk add --simulate --allow-untrusted --network=no \
  --repositories-file /dev/null --repository "$PWD/rollback/aarch64" \
  'libcamera=99990.7.2-r19' \
  'libcamera-ipa=99990.7.2-r19' \
  'pipewire-spa-libcamera=1.6.8-r5' \
  'snapshot=50.0-r1' \
  'snapshot-lang=50.0-r1'
```

Require exactly five downgrades and no removals. Exact-version `apk add`
temporarily pins those versions in `/etc/apk/world`; preserve a pre-test copy
and hash, then remove only the pins added by this command after verifying the
installed versions. Never replace the whole file with an unverified copy.

Never use `apk upgrade --available` with either partial repository. apk-tools
3 may reconcile the whole installation against that partial index and remove
unrelated packages.
