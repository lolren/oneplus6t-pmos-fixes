# NFC readiness

The OnePlus 6T postmarketOS support page currently lists NFC as partial. This
project therefore treats NFC as a bounded tag-reader workstream, not as a
claim of payment support or Android-level firmware support.

## Read-only report

After installing the project package, collect a report without enabling the
reader or changing radio state:

```sh
pmos-check-nfc --output /private/path/oneplus6t-nfc.txt
```

The report records:

- NFC and rfkill entries exposed by sysfs;
- `/dev/nfc*` and `/dev/pn*` device nodes;
- whether `rfkill`, `nfc-list`, `nfc-poll` and `systemctl` are installed; and
- the state of the optional `neard.service` and `pcscd.service` units.

For the phone's kernel NCI controller, the preferred userspace is the
`neard` package and its `nfctool` utility. On Alpine/postmarketOS channels
where those packages are available, install the daemon package and its
systemd subpackage, then start the daemon:

```sh
sudo apk add neard neard-systemd
sudo systemctl enable --now neard.service
```

The checker uses `nfctool -l` for non-invasive adapter discovery, selects the
reported adapter (for example `nfc0`), and runs `nfctool -d nfc0 -p` for an
explicit poll. `nfc-list -v` remains a fallback for
libnfc-compatible external readers; it is not assumed to drive the phone's
kernel NCI adapter. The Linux NFC subsystem exposes controller management and
polling through generic netlink, which is the interface used by `nfctool`.

The default mode does not start polling. It is safe to run while diagnosing a
phone that may have an incomplete NFC driver.

## Explicit tag poll

Only after the report shows a controller and an unblocked radio, and after a
tag is placed beside the phone, explicitly request a userspace poll:

```sh
sudo pmos-check-nfc --poll
```

This runs `nfctool -d nfc0 -p` when the phone's kernel-NCI adapter is present,
or `nfc-list -v` for a compatible external reader. It may activate the reader
and requires root because polling changes adapter state. The checker restores
the adapter to its previous powered-down state when the explicit poll exits or
is interrupted. It is not part of the default health check. A successful
acceptance requires detecting a real tag and recording its UID/available NDEF
data, then repeating the test after restarting the relevant userspace service.
No payment functionality is implied.

## Reproducibility

The report accepts `PMOS_NFC_SYSFS_ROOT`, `PMOS_NFC_DEV_ROOT`,
`PMOS_NFC_RFKILL`, `PMOS_NFC_SYSTEMCTL`, `PMOS_NFC_LIST`, `PMOS_NFC_POLL`,
`PMOS_NFC_TOOL`, `PMOS_NFC_DEVICE` and `PMOS_NFC_POLL_PRIVILEGED` overrides. The
fixture-driven `tests/test-nfc-report.sh` verifies that a discovered `nfc0` is
passed to the poll command, an unprivileged poll is refused clearly, and the
no-poll default remains hardware-free.

On the recovered reference phone, `neard.service` is enabled and active and
`nfctool -l` exposes `nfc0` with the expected NCI protocols. A real tag still
needs to be placed beside the phone for final UID/NDEF acceptance.
