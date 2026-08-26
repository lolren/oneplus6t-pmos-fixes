# USB transport and recovery evidence

`scripts/check-device-transport` is a host-side, read-only diagnostic for a
OnePlus 6T connected over USB. Run it on the Linux computer that has the phone
attached, not inside the phone's postmarketOS shell:

```sh
./scripts/check-device-transport \
  --output /tmp/oneplus6t-device-transport.txt
```

It checks the following without authenticating or changing state:

- whether Linux identifies a CDC-NCM network interface as `OnePlus_6T`;
- whether that interface is up and has a local IPv4 address;
- whether `172.16.42.1` answers ICMP;
- whether TCP port 22 accepts connections and sends an SSH protocol banner;
- the count of ADB devices and whether an ADB description identifies
  `fajita`/OnePlus; and
- the count returned by the read-only `fastboot devices` command.

The command never supplies a password, sends an ADB shell command, resets USB,
reboots, invokes a fastboot write operation, changes routes or changes the
phone. The host ADB client may start its local enumeration daemon while
listing devices; it does not execute a command on the phone.
Serial numbers and raw ADB/fastboot output are intentionally not copied into
the report.

## Interpreting the report

`transport_mode=postmarketos-usb-network` means the phone is booted into
postmarketOS's USB network gadget. An empty `fastboot devices` result is
expected in that mode; the USB product database may still display a generic
Qualcomm/Google fastboot label for the same vendor/product ID.

The important SSH combinations are:

| Report | Meaning |
| --- | --- |
| `ping=pass`, `ssh_tcp=pass`, `ssh_banner=pass` | The network path and SSH service are usable. |
| `ping=pass`, `ssh_tcp=pass`, `ssh_banner=missing` | The kernel/network path is alive, but the phone-side SSH service or userspace is not speaking SSH. Do not infer that login works. |
| `ping=fail`, `ssh_tcp=fail` | No usable IP path was confirmed; check the USB gadget, cable, interface address and phone boot state. |
| `adb_oneplus=present` | ADB identifies a OnePlus/fajita device; this is a separate transport from NCM and SSH. |
| `fastboot_devices` greater than zero | A fastboot device is visible, but the report does not assume it is the OnePlus when other Android devices are attached. |

Use the report together with the phone-side recovery procedure. A surviving
ping or open TCP socket is not sufficient evidence to install packages,
modify a Waydroid overlay or flash anything.
