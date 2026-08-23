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

Do not unload the live `imx371` module for camera testing. On the tested stock
kernel its remove path warned in the Qualcomm camera-clock driver, and lockdown
rejects an unsigned trial module. Test camera kernel changes through a normal,
signed postmarketOS kernel package. Installing that package and rebooting into
it each require explicit approval after the stock APK and rollback command have
been recorded.

Any future low-level change requires verified stock recovery material, a
device-specific backup, an explicit rollback procedure, and separate user
approval. Fairphone 5 kernels, DTBs, modules, services and boot images are not
compatible with this device.

The mobile-data rollback script reads the UUID recorded at installation and
refuses to delete a non-GSM profile. Existing user-created profiles are left
untouched.
