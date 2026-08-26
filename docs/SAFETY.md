# Safety policy

The OnePlus 6T is treated as non-replaceable hardware.

## Allowed scope

The current scripts may:

- inspect ModemManager and NetworkManager state;
- create or delete a NetworkManager profile that they own;
- enable normal system time synchronization;
- perform bounded connectivity tests;
- inspect camera/media state and private captures without publishing them;
- inspect Waydroid mounts, load and I/O pressure with
  `pmos-check-waydroid-health` without changing services or storage;
- build kernel or userspace packages on the host without installing them;
- simulate or explicitly apply the exact manifest-verified native r7/r5,
  r7/r4, r7/r1 and r6/r0 camera generations through
  `manage-camera-generation`;
- run `pmos-safe-upgrade`, which simulates an ordinary `apk upgrade` and blocks
  camera-critical package changes before activation; and
- stop and start the Waydroid container/session; and
- install a matched Android userspace camera bundle into the Waydroid overlay
  after preserving replaced files and recording newly created paths.

## Prohibited scope

These scripts must never:

- invoke `qbootctl`;
- change A/B slot metadata;
- modify GPT attributes or partition tables;
- change UFS boot LUN configuration;
- flash bootloader or firmware partitions;
- write through EDL; or
- reboot while storage or flashing operations are active.

Do not unload live camera sensor or actuator modules for testing. On the tested
kernel the IMX371 remove path warned in the Qualcomm camera-clock driver, and
lockdown rejects unsigned trial modules. Test kernel changes through a normal,
signed postmarketOS package. Installing that package and rebooting into it
requires the exact installed generation and rollback commands to be recorded
first; the current native camera release is r7/r5 with the manifest-verified
r7/r4 rollback.

Do not use `apk upgrade --available` with a partial local rollback repository.
For ordinary updates use `pmos-safe-upgrade`; it blocks transactions touching
the camera-critical package set and directs those changes through the signed
generation manager. It also records normalized simulation and apply operation
lists and refuses to report success if apk applies a different transaction.
That is an alarm after an unexpected apply, not an automatic rollback. The
safe wrapper does not claim that an arbitrary kernel or userspace update is
camera-compatible.

On apk-tools 3, `apk upgrade --available` can reconcile the whole installed
system against a partial local rollback repository and remove unrelated
packages. A camera rollback must use exact manifest version constraints and
must list only the documented generation transition in simulation.

The historical Advanced Snapshot/PipeWire rollback must list exactly the three
r7/r1-to-r6/r0 downgrades. The current r7/r5-to-r7/r4 rollback lists only the
two app downgrades. Supplying the local PipeWire APK temporarily adds a
world identity constraint; simulate its removal and require reverse dependencies
to retain the installed plugin before removing only that constraint. The guarded
commands are in `packaging/pmaports/README.md`.

Because the rebuilt r8 kernel keeps the same release string, its package replaces
modules under the running kernel's module directory. After a successful kernel
package transaction, do not open the camera or load/unload modules before the
approved reboot.

Any future low-level change requires verified stock recovery material, a
device-specific backup, an explicit rollback procedure, and separate user
approval. Fairphone 5 kernels, DTBs, modules, services and boot images are not
compatible with this device.

Treat the Waydroid HAL, libcamera, libcamera-base, libc++ runtime, IPA module,
IPA signature, tuning and provider override as one versioned set. Never update
only one library, never place ARMv7 Android objects in native `/usr/lib`, and
never restore the complete overlay from an old snapshot that may overwrite
unrelated changes. A Waydroid rollback restores only files recorded as present
and removes only paths explicitly recorded as absent before installation. A
Waydroid restart is sufficient for this userspace overlay; it does not require
a phone reboot.

Before an overlay install or rollback, run:

```sh
pmos-check-waydroid-health --status --processes
```

Proceed only when `rootfs_mounts=0` and
`overlay_precondition=pass`. A mounted rootfs or non-zero I/O pressure means
the storage path is not safe for a copy operation; recover the phone first.
When `--processes` reports D-state installer, Waydroid or reboot helpers, do
not assume that sending a signal succeeded; repeat the report after recovery.

The mobile-data rollback script reads the UUID recorded at installation and
refuses to delete a non-GSM profile. Existing user-created profiles are left
untouched.
