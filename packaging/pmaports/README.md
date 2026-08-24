# Reproducible OnePlus 6T camera packages

`0001-oneplus6t-camera-stack.patch` integrates the complete camera stack into
pmaports: five SDM845 kernel patches, eleven libcamera patches, three tuning
files, checksums and package revision bumps. It contains no APK, boot image,
firmware, vendor library, photograph or device-specific identifier.

## Reviewed base and build

The integration patch cleanly applies to pmaports commit
`073ff887b0e18c4c80bd94098fda035e0e20d28b`.

```sh
git checkout 073ff887b0e18c4c80bd94098fda035e0e20d28b
git apply --check --whitespace=nowarn /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch
git apply --whitespace=nowarn /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-camera-stack.patch

pmbootstrap -p "$PWD" build --arch aarch64 libcamera
pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
```

If pmaports has moved, rebase the individual source patches. Do not force a
rejected integration hunk. The reference builds used pmbootstrap 3.11.0 and
completed for aarch64.

## Package revisions

Applying the integration patch to the reviewed base produces:

- `linux-postmarketos-qcom-sdm845-7.1_rc1-r8`;
- `libcamera-99990.7.2-r19`; and
- `libcamera-ipa-99990.7.2-r19`.

The high revisions preserve ordering above the camera packages already used
during live diagnosis. They do not imply nineteen public releases.

## Reference artifacts

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk` | `232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e` |
| `libcamera-99990.7.2-r19.apk` | `073eb1f4b6d26d5573847724b13d2fe9ce79d4b578fa0a4e7097b1a108c79c91` |
| `libcamera-ipa-99990.7.2-r19.apk` | `fb9b5040714462c06750a28916c3ced706cd254ac502974c446b48a1325b2a0b` |
| `libcamera-tools-99990.7.2-r19.apk` | `969bcaf58e7133543bdaf060bbd60c14568f4a3cac56214e55178871269c47bd` |

Independent builds may differ because APK metadata and signing keys are local.
Verify source, package version, architecture and behavior as well as hashes.
The reference IMX519 module has matching `7.1.0-rc1-sdm845` vermagic and a
PKCS#7 SHA-512 signature from its kernel build key. The final kernel package
does not contain the discarded actuator-readiness or diagnostics experiments.

## Current installation and rollback baseline

The reference phone currently runs:

- kernel package `7.1_rc1-r8`; and
- `libcamera` plus `libcamera-ipa` `99990.7.2-r19`.

The exact r18 packages retained below are the userspace rollback baseline. Keep
their APKs, or verified version-matched rebuilds, before reproducing the r19
upgrade. Do not assume that an online repository will continue to carry the old
versions.
The retained rollback APK SHA-256 values are
`360e1c718650907065f8322d1d01a57b27591b7ca827b3a0e8821c7082d93a63`
for `libcamera` and
`4f1748ff710b67b6ef7d8f4e32c1e5f33dc84fa9c1d508192e4a88dc12285083`
for `libcamera-ipa`.

## Installation boundary

The build commands above do not copy or install anything, update boot files or
reboot. Installation requires fresh explicit approval. The completed r19
change was userspace-only and did not require a reboot.

Stage patched and rollback APKs in separate offline repositories with an
`aarch64/APKINDEX.tar.gz`. From the directory containing `patched/`, simulate
first:

```sh
apk upgrade --simulate --allow-untrusted --network=no \
  --repositories-file /dev/null --repository "$PWD/patched" \
  libcamera libcamera-ipa
```

Starting from the documented r18 baseline, it must list exactly these
transitions and no removal:

```text
libcamera-ipa  99990.7.2-r18 -> 99990.7.2-r19
libcamera      99990.7.2-r18 -> 99990.7.2-r19
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
  --repositories-file /dev/null --repository "$PWD/rollback" \
  'libcamera=99990.7.2-r18' \
  'libcamera-ipa=99990.7.2-r18'
```

Require exactly two downgrades and no removals. Exact-version `apk add`
temporarily pins those versions in `/etc/apk/world`; preserve a pre-test copy
and merge it carefully afterward.

Never use `apk upgrade --available` with either partial repository. apk-tools
3 may reconcile the whole installation against that partial index and remove
unrelated packages.
