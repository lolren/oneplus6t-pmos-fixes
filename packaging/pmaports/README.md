# Reproducible front-camera packages

`0001-oneplus6t-front-camera.patch` integrates the front-camera changes into
pmaports. It adds three kernel patches, one libcamera patch, their checksums and
the required package revision bumps. It contains no APK, boot image, firmware,
vendor library, test photograph or device-specific data.

## Reviewed base

The integration patch was built and clean-apply tested against pmaports commit
`073ff887b0e18c4c80bd94098fda035e0e20d28b`. If pmaports has moved, first try
`git apply --check`; rebase the individual patches rather than forcing a
rejected hunk.

From a clean pmaports checkout at that revision:

```sh
git apply --check /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-front-camera.patch
git apply /path/to/oneplus6t-pmos-fixes/packaging/pmaports/0001-oneplus6t-front-camera.patch

pmbootstrap -p "$PWD" build --arch aarch64 linux-postmarketos-qcom-sdm845
pmbootstrap -p "$PWD" build --arch aarch64 libcamera
```

The tested builder was pmbootstrap 3.11.0. The kernel recipe becomes
`7.1_rc1-r5`; libcamera and its IPA become `99990.7.2-r3`.

## Reference artifacts

The 23 August 2026 build produced:

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r5.apk` | `e29453dc71b50225141be668beedc9a96650ae429b5623a498b5a0297122c7eb` |
| `libcamera-99990.7.2-r3.apk` | `1bf0c7419679673afd4f9b27b69026f1a8fe171f8e24b526bdca99ad7926041b` |
| `libcamera-ipa-99990.7.2-r3.apk` | `02387288fedb6f9f002c757185f5942d9e15d6913298ef21bdff176e30914ea4` |

An independent build can differ byte-for-byte because APK metadata and signing
keys are build-local. Verify behavior and source content as well as filenames.
The reference kernel's IMX371 module has matching vermagic and a PKCS#7
signature from its own kernel build key.

Version-matched rollback packages were also built from the unmodified pmaports
recipes at the same commit:

| Package | SHA-256 |
| --- | --- |
| `linux-postmarketos-qcom-sdm845-7.1_rc1-r4.apk` | `c8fd136e9e61de9fc5c2a0d8ff2b7c3dfe925f3ee371bc5dbceb384dd0792845` |
| `libcamera-99990.7.2-r2.apk` | `e729b31d16e91c6a302ed6e1f4dc1c70283d0a10b9c618d2c26da4cf5fc3ec8c` |
| `libcamera-ipa-99990.7.2-r2.apk` | `f4d503d2f551128bdc5b2473faa2e5a9735f82e8bada769e36d22391c20cf286` |

They match the installed package versions and source recipes, but they are
fresh local builds rather than byte-for-byte copies of the APKs originally
installed on the phone.

## Installation boundary

These commands build packages only. They do not copy anything to the phone,
install a kernel, update boot files or reboot. Do not test by unloading the
live `imx371` module. Before any live installation, retain the exact installed
stock versions or version-matched rollback builds, write down the downgrade
command, verify package architecture/version and checksums, and obtain explicit
approval for both installation and the subsequent reboot.

## Audited live-test transaction

The reference phone runs apk-tools 3.0.7. Patched and rollback APKs were staged
in separate local repositories, each with an `aarch64/APKINDEX.tar.gz`. With
the shell in the directory containing `patched/`, first simulate the upgrade:

```sh
apk upgrade --simulate --allow-untrusted --network=no \
  --repositories-file /dev/null --repository "$PWD/patched" \
  linux-postmarketos-qcom-sdm845 libcamera libcamera-ipa
```

It must list exactly these three transitions and no removals:

```text
linux-postmarketos-qcom-sdm845 7.1_rc1-r4 -> 7.1_rc1-r5
libcamera-ipa                  99990.7.2-r2 -> 99990.7.2-r3
libcamera                      99990.7.2-r2 -> 99990.7.2-r3
```

After explicit approval, repeat the same command as root without `--simulate`.
This uses `apk upgrade`, so it does not add local-package identity pins to
`/etc/apk/world`. Verify the installed versions before rebooting.

The kernel release string is unchanged, so the package replaces modules below
the running kernel's module path. Do not open the camera, unload/load modules
or continue normal use between the successful package transaction and the
approved reboot.

### Rollback

The rollback solver was tested in a user-owned copy of the phone's complete APK
database. From the directory containing `stock/`, this simulation selected
exactly three downgrades:

```sh
apk add --simulate --allow-untrusted --network=no \
  --repositories-file /dev/null --repository "$PWD/stock" \
  'linux-postmarketos-qcom-sdm845=7.1_rc1-r4' \
  'libcamera=99990.7.2-r2' \
  'libcamera-ipa=99990.7.2-r2'
```

Only after checking that output, repeat it as root without `--simulate`. This
exact-version `apk add` temporarily pins the three rollback versions in
`/etc/apk/world`. If no unrelated package changes were made during the test,
restore the pre-test world-file backup after confirming all three downgrades,
then reboot. If the world file changed for another reason, merge it instead of
overwriting it.

Never use `apk upgrade --available` with either three-package repository. An
isolated simulation showed that apk-tools 3 treats `--available` globally and
would prune unrelated packages missing from that partial repository.
