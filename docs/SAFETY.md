# Safety policy

The OnePlus 6T is treated as non-replaceable hardware.

## Allowed scope

The current scripts may:

- inspect ModemManager and NetworkManager state;
- create or delete a NetworkManager profile that they own;
- enable normal system time synchronization;
- perform bounded connectivity tests;
- inspect camera/media state and private captures without publishing them;
- build kernel or userspace packages on the host without installing them;
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
signed postmarketOS package. Installing that package and rebooting into it each
require fresh explicit approval after the current r8/r24/r7/r3 plus Advanced
Snapshot r1 state, retained r6/r0 and r20/r6/r2 APKs, and exact rollback
commands have been recorded.

Do not use `apk upgrade --available` with a partial local rollback repository.
On apk-tools 3 it can reconcile the whole installed system against that partial
index and remove unrelated packages. The immediate userspace-camera rollback
uses exact version constraints and must list only the two documented r24-to-r23
downgrades in simulation.

The separate Advanced Snapshot/PipeWire rollback must list exactly the three
r7/r1-to-r6/r0 downgrades. Supplying the local PipeWire APK temporarily adds a
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

The mobile-data rollback script reads the UUID recorded at installation and
refuses to delete a non-GSM profile. Existing user-created profiles are left
untouched.
