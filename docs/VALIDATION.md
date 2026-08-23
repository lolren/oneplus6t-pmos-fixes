# Validation record

All values below are sanitized. No IMEI, IMSI, ICCID, telephone number, account
credential, SSH key or device-unique serial is recorded.

## Environment

Validated on 23 August 2026:

- device: OnePlus 6T (`oneplus-fajita`), 8 GB / 128 GB;
- distribution: postmarketOS edge;
- kernel: `7.1.0-rc1-sdm845`;
- libcamera: `99990.7.2-r2` (upstream 0.7.2);
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

## Front camera results

The front sensor was identified as IMX371. The stock pipeline selected a
4656x3496 packed RAW10 input for a 1920x1080 processed stream. A neutral raw
capture had a stable 4x4 Quad Bayer layout with same-colour physical 2x2
blocks. The stock conventional Bayer output reproduced both reported defects:
near-monochrome colour and a fine regular grid.

Offline 2x2 cluster binning produced a 2304x1728 ordinary RGGB mosaic. A normal
demosaic removed the grid and restored independent channel response. Input and
output captures remain private and are not present in this repository.

The factory binned-mode register sequence was decoded independently and then
compared with the generated kernel table: all 83 address/value entries match.
The kernel patches pass `git diff --check` and the Linux kernel strict
`checkpatch.pl` test. The libcamera 0.7.2 helper patch applies to the packaged
source, and an equivalent patch was rebased onto current upstream `master`.

The final pmaports integration patch cleanly applies to pmaports commit
`073ff887b0e18c4c80bd94098fda035e0e20d28b`. Using pmbootstrap 3.11.0,
clean `aarch64` builds completed for both packages:

- `linux-postmarketos-qcom-sdm845-7.1_rc1-r5.apk`, SHA-256
  `e29453dc71b50225141be668beedc9a96650ae429b5623a498b5a0297122c7eb`;
- `libcamera-99990.7.2-r3.apk`, SHA-256
  `1bf0c7419679673afd4f9b27b69026f1a8fe171f8e24b526bdca99ad7926041b`;
  and
- `libcamera-ipa-99990.7.2-r3.apk`, SHA-256
  `02387288fedb6f9f002c757185f5942d9e15d6913298ef21bdff176e30914ea4`.

The packaged IMX371 module has matching `7.1.0-rc1-sdm845` vermagic, a PKCS#7
SHA-512 signature from the build-time kernel key, and a compiled gain maximum
of 960. The packaged OnePlus 6T DTB advertises 654 MHz and 399 MHz for IMX371.
The packaged simple IPA contains the registered `imx371` helper. APK hashes
identify this reference build; independent package signatures and build
metadata can make a clean rebuild bytewise different.

Unmodified, version-matched rollback builds also completed for the currently
installed kernel `7.1_rc1-r4`, libcamera `99990.7.2-r2` and libcamera IPA
`99990.7.2-r2`. Their file sets match their corresponding patched packages.
They are local rebuilds of the same pmaports recipes, not bytewise copies of the
APKs that were originally installed.

All six APKs were copied to user storage on the phone and passed `sha256sum -c`.
An offline local-repository simulation selected exactly the intended kernel,
libcamera and IPA upgrades; a second policy check confirmed that simulation
left the real system on `r4`/`r2`/`r2`.

Upgrade and rollback were then exercised non-destructively in a user-owned copy
of the phone's complete APK database with package scripts and commit hooks
disabled. The copied database upgraded exactly those three packages to
`r5`/`r3`/`r3`, and the exact-version rollback downgraded exactly those three to
`r4`/`r2`/`r2`. This also exposed and rejected an unsafe alternative:
`apk upgrade --available` against the partial rollback repository planned to
prune unrelated packages. It was never run against the real package database.

An attempted temporary module test was rejected by lockdown before custom code
could execute. Unloading the stock module exposed a warning in its existing
camera-clock remove path; the stock module and sensor binding were restored,
and fresh libcamera enumeration again found all three cameras. Live binned-mode
validation therefore requires the normal signed kernel package and an approved
reboot. Do not use module swapping for this device.

## Remaining validation

A normal reboot test has not yet been performed for this repository revision.
NetworkManager profile persistence and autoconnect were verified with a manual
down/up cycle; boot-time reconnection must be recorded separately after an
explicitly approved reboot.

The front camera still requires live validation of the signed patched kernel,
followed by still/video, colour, grid, exposure and repeated-open tests listed
in `CAMERA.md`. No successful patched-camera result is claimed yet.
