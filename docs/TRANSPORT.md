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
- whether TCP port 22 accepts connections, whether a bounded probe was
  refused/filtered, and whether it sends an SSH protocol banner;
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
| `ping=pass`, `ssh_probe=timeout-or-filtered` | The phone answers ICMP but drops or does not answer TCP/22. Check the phone-side firewall and `sshd` state; this is not evidence of a cable fault. |
| `ping=fail`, `ssh_tcp=fail` | No usable IP path was confirmed; check the USB gadget, cable, interface address and phone boot state. |
| `adb_oneplus=present` | ADB identifies a OnePlus/fajita device; this is a separate transport from NCM and SSH. |
| `fastboot_devices` greater than zero | A fastboot device is visible, but the report does not assume it is the OnePlus when other Android devices are attached. |

Use the report together with the phone-side recovery procedure. A surviving
ping or open TCP socket is not sufficient evidence to install packages,
modify a Waydroid overlay or flash anything.

## Phone-side recovery

The OnePlus 6T device guide documents SSH over USB networking for a booted
system. On newer postmarketOS mobile images, USB access may also be disabled
until the phone's USB-mode notification is used to select USB networking; this
is part of the postmarketOS USB-stack change described in the
[official USB-stack announcement](https://postmarketos.org/edge/2025/12/28/USB-framework-rework/).

Once USB networking is selected, use the phone's local terminal. If the fixes
package is installed, the reproducible recovery command is:

```sh
sudo pmos-enable-ssh --apply
```

It detects systemd or OpenRC, starts `sshd`, enables it for the next boot and
verifies a TCP/22 listener. It does not change firewall rules. If the helper is
not installed, use the init-specific fallback below. For an OpenRC image,
which is the command form in the
[OnePlus 6T device guide](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29),
run:

```sh
sudo service sshd start
sudo rc-update add sshd default
ss -lnt | grep ':22 '
```

For a systemd image, use the equivalent:

```sh
sudo systemctl enable --now sshd.service
ss -lnt | grep ':22 '
```

If the service is missing, install the image's OpenSSH server package from its
normal postmarketOS repository before retrying. Do not change firewall rules
blindly: first record `sudo nft list ruleset` (or `sudo iptables -S`) and the
service status. A successful `ss` listener plus the host report's
`ssh_probe=accepted` and `ssh_banner=pass` is the minimum management gate;
ping alone is not enough.
