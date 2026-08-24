# Safety policy

The OnePlus 6T is treated as non-replaceable hardware.

## Allowed scope

The current scripts may:

- inspect ModemManager and NetworkManager state;
- create or delete a NetworkManager profile that they own;
- enable normal system time synchronization;
- perform bounded connectivity tests;
- inspect camera/media state and private captures without publishing them; and
- build kernel or userspace packages on the host without installing them.

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
require fresh explicit approval after the current r8/r19 state, retained r18
APKs and exact rollback command have been recorded.

Do not use `apk upgrade --available` with a partial local rollback repository.
On apk-tools 3 it can reconcile the whole installed system against that partial
index and remove unrelated packages. The next userspace-camera rollback uses
exact version constraints and must list only the two libcamera downgrades in
simulation.

Because the rebuilt r8 kernel keeps the same release string, its package replaces
modules under the running kernel's module directory. After a successful kernel
package transaction, do not open the camera or load/unload modules before the
approved reboot.

Any future low-level change requires verified stock recovery material, a
device-specific backup, an explicit rollback procedure, and separate user
approval. Fairphone 5 kernels, DTBs, modules, services and boot images are not
compatible with this device.

The mobile-data rollback script reads the UUID recorded at installation and
refuses to delete a non-GSM profile. Existing user-created profiles are left
untouched.
