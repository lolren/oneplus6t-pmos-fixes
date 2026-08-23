# Validation record

All values below are sanitized. No IMEI, IMSI, ICCID, telephone number, account
credential, SSH key or device-unique serial is recorded.

## Environment

Validated on 23 August 2026:

- device: OnePlus 6T (`oneplus-fajita`), 8 GB / 128 GB;
- distribution: postmarketOS edge;
- kernel: `7.1.0-rc1-sdm845`;
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
- a second installer run replacing its first managed profile transactionally;
  and
- isolated `--no-activate` installation and rollback, confirming that both the
  test profile and marker were removed while the real SMARTY profile remained
  active.

The carrier did not assign a global IPv6 address, so IPv6 was reported as
skipped rather than failed. The final active Internet APN is `mob.asm.net`; the
separate active `ims` bearer belongs to `81voltd`.

## Time results

`systemd-timesyncd` is enabled and active, `NTPSynchronized=yes`, and
`/var/lib/systemd/timesync/clock` has a current timestamp. The hardware RTC
still reports 1970; no attempt was made to write it.

## Remaining validation

A normal reboot test has not yet been performed for this repository revision.
NetworkManager profile persistence and autoconnect were verified with a manual
down/up cycle; boot-time reconnection must be recorded separately after an
explicitly approved reboot.
