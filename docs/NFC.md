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

The default mode does not start polling. It is safe to run while diagnosing a
phone that may have an incomplete NFC driver.

## Explicit tag poll

Only after the report shows a controller and an unblocked radio, and after a
tag is placed beside the phone, explicitly request a userspace poll:

```sh
pmos-check-nfc --poll
```

This runs `nfc-list -v` when available. It may activate the reader and is not
part of the default health check. A successful acceptance requires detecting a
real tag and recording its UID/available NDEF data, then repeating the test
after restarting the relevant userspace service. No payment functionality is
implied.

## Reproducibility

The report accepts `PMOS_NFC_SYSFS_ROOT`, `PMOS_NFC_DEV_ROOT`,
`PMOS_NFC_RFKILL`, `PMOS_NFC_SYSTEMCTL`, `PMOS_NFC_LIST` and `PMOS_NFC_POLL`
overrides. The fixture-driven `tests/test-nfc-report.sh` uses those overrides
to test controller discovery and the no-poll default without NFC hardware.

Physical acceptance is still pending recovery of the reference phone.
