# Cellular data

## Observed failure

On a fresh postmarketOS edge installation on `oneplus-fajita`:

- ModemManager detected the Qualcomm QRTR modem.
- LTE registered at home on operator `23420` (`3 UK`).
- Packet service was attached and signal quality was healthy.
- `81voltd` created its separate `ims` bearer for telephony services.
- NetworkManager had no Internet-data GSM profile, address or default route.

Creating a NetworkManager profile with the documented SMARTY APN produced a
QMAP data interface, carrier DNS, a CGNAT IPv4 address and a working default
route. Cellular-bound ping, DNS and HTTPS then succeeded.

The IMS bearer is not a general Internet bearer. Its existence does not mean a
user-data APN has been configured.

## Carrier-neutral selection

NetworkManager supports `gsm.auto-config=yes`. It obtains the APN, username and
password from the standard Mobile Broadband Provider database. This project
uses that mechanism when one SIM operator code maps to one provider.

MCC/MNC alone cannot reliably identify every MVNO. The database shipped during
validation maps `23420` to both Three and Superdrug, while SMARTY is absent. A
controlled test with database auto-configuration selected `superdrug.net` for
a SMARTY SIM. Although the network happened to establish a bearer, another
provider's APN is not a correct or portable configuration.

The installed `20251101` database describes MCC/MNC matching but has no SIM
GID field. Upstream database `main` added `<gid1>` after that release, though
current NetworkManager still ignores it. ModemManager exposes GID1/GID2 without
exposing the IMSI or SIM serial. The tested SMARTY SIM reports GID1 `0309`;
SMARTY's own setup page publishes MCC `234`, MNC `20`, MVNO type GID and
value `0309`.

`configure-mobile-data` therefore applies this order:

1. an explicit APN supplied by the user;
2. the most-specific MCC/MNC + GID match in `data/mvno-apns.psv`;
3. an exact MCC/MNC + GID1 match in a newer provider database;
4. NetworkManager database auto-configuration when exactly one unrestricted
   provider matches the MCC/MNC; or
5. a safe refusal that asks for an explicit APN.

For a database GID match, the helper reads that provider's first Internet APN
and credentials itself. For an unambiguous unrestricted provider, it delegates
to NetworkManager with `gsm.auto-config=yes`.

No public carrier database is guaranteed to contain every plan worldwide.
This design covers the standard database while making missing and ambiguous
cases explicit instead of silently selecting the wrong provider.

## Installation

First inspect the choice without root or changes:

```sh
./scripts/configure-mobile-data --dry-run
```

A SMARTY SIM with the validated GID produces:

```text
operator_code=23420
gid1=0309
selection=mvno-overlay
provider=SMARTY
apn=mob.asm.net
ip_mode=ipv4
auto_config=no
```

Create and activate the persistent profile, then test only the cellular path:

```sh
sudo ./scripts/configure-mobile-data
./scripts/check-mobile-data
```

`check-mobile-data` binds its probes to the modem interface, so it remains
useful while Wi-Fi is preferred. To prove the system-wide fallback path as
well, run the explicit cellular-only test:

```sh
./scripts/test-cellular-only
```

It snapshots the initial Wi-Fi radio state and every active Wi-Fi profile
UUID-to-device mapping, disables Wi-Fi, waits for the system default route to
match the modem bearer, and verifies native DNS and HTTPS. It restores the
original Wi-Fi radio/profile state on normal, failure and signal exits. Radio
re-enable can complete before a Wi-Fi interface becomes available, so profile
reactivation is bound to its original interface and retried within a fixed
bound. If Wi-Fi was already disabled, it leaves it disabled. A failed
preflight makes no network change.

When Waydroid is already running, include its NAT path:

```sh
./scripts/test-cellular-only --with-waydroid
```

This additionally checks raw IPv4 and DNS-name connectivity inside Android.
For a normal login user, sudo is validated before Wi-Fi changes and used only
for the Wi-Fi radio/profile mutations and optional
`waydroid status`/`waydroid shell`; all inspection and native traffic probes
stay in the login session. Root runs those commands directly. The test does
not start Waydroid, create or recycle a bearer, edit an APN, or touch boot
state. It can briefly interrupt network applications, so it is never part of
the default observational acceptance run.

With the runtime package installed, use `pmos-test-cellular-only` in place of
the source path. A bounded wait can be selected with `--wait-seconds N`, where
`N` is 10 through 180 seconds.

The profile is bound to the detected SIM operator with
`gsm.sim-operator-id`, uses unlimited autoconnect retries, and follows the IP
mode recorded in the reviewed rule. SMARTY's current official instructions
specify IPv4.

When the packaged systemd unit is present, successful configuration also
enables `oneplus6t-mobile-data-watchdog.timer`. For a profile that predates the
watchdog, enable it once without rebuilding the connection:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now oneplus6t-mobile-data-watchdog.timer
```

For a missing provider:

```sh
sudo ./scripts/configure-mobile-data \
  --provider "Example carrier" \
  --apn example.apn
```

Use `--username` and `--password-stdin` only when the provider requires public
APN credentials. NetworkManager stores supplied credentials as a connection
secret; they are not written to this repository or printed by the tool.
Use `--ip-mode ipv4`, `ipv6` or `ipv4v6` if the carrier documents a mode that
differs from the default.

## Transaction and rollback behavior

The installer creates a candidate profile before replacing a profile it
already owns. It activates the candidate first. If activation fails, the
candidate is removed and the previous managed profile is reactivated. Existing
user-created profiles are never modified.

After success, the managed UUID is atomically recorded at:

```text
/var/lib/oneplus6t-pmos-fixes/mobile-data-profile.uuid
```

Rollback is deliberately narrow:

```sh
sudo ./scripts/remove-mobile-data
```

The remover validates the UUID and connection type, refuses symbolic-link
markers, disables the associated watchdog timer and deletes only that managed
GSM profile.

## Stale-bearer recovery

The Qualcomm IPA/QMAP stack can receive an ordinary network-side data-bearer
deactivation while Wi-Fi is preferred. In the reproduced failure,
ModemManager correctly marked the Internet bearer disconnected and deleted
`qmapmux0.0`, but NetworkManager continued to report the managed connection as
`activated`, retained `GENERAL.IP-IFACE=qmapmux0.0` and never retried. Unlimited
NetworkManager autoconnect retries do not help while that stale active state
persists.

`mobile-data-watchdog` validates all of these together:

- the UUID is the project-owned GSM profile recorded in the root-only marker;
- NetworkManager reports it activated;
- the reported interface still exists with a global address; and
- that interface owns an IPv4 or IPv6 default route in any policy table.

Healthy profiles are read-only no-ops. Inactive profiles are left to normal
NetworkManager autoconnect. A stale activated profile is cycled only with
`--repair`, only while the modem is registered, never while ModemManager lists
an active voice call, and no more than once every five minutes. The systemd
timer runs this repair mode every five minutes with a randomized/coalesced
delay to limit wakeups.

The live acceptance test explicitly disconnected only the `mob.asm.net`
bearer. NetworkManager reproduced its stale activated state with the interface
absent; the watchdog reconnected `qmapmux0.0`, restored its address/default
route and passed three interface-bound pings. The idle IMS bearer briefly
reconnected as part of modem recovery and was restored by `81voltd` within
eight seconds. Active calls are therefore a hard no-repair condition.

Run a read-only check at any time:

```sh
sudo pmos-mobile-data-watchdog --check
systemctl status oneplus6t-mobile-data-watchdog.timer
```

## Adding an MVNO rule

Rules use pipe-separated fields:

```text
operator-code|gid1|gid2|provider|apn|ip-mode|username|password|source
```

Use `*` only for a field that genuinely may have any value and `-` for no
username or password. Exact GID matches take precedence over wildcard matches.
Supported IP modes are `ipv4`, `ipv6` and `ipv4v6`.

Every rule must cite a carrier or platform source that publishes the APN and
matching identity. Add a fixture and test before submitting it. See
[CONTRIBUTING.md](../CONTRIBUTING.md).

When upstream provider data already has a matching `<gid1>`, do not duplicate
it in the overlay.

## Diagnostics

The checker finds the active modem instead of assuming modem zero, identifies
the cellular default-route interface, and binds transport tests to it. A
successful run reports LTE state plus any available IPv4/IPv6 tests, cellular
DNS and cellular HTTPS.

The separate cellular-only test requires `curl`; it uses `resolvectl` when
available and otherwise the portable `getent` resolver path. Its
machine-readable report includes the selected cellular interface, native
default route, resolver method, HTTPS result, optional Waydroid results and
Wi-Fi restoration result.

An IPv6 skip is informational when the carrier supplies only IPv4. A raw IP
ping succeeding while DNS/HTTPS fails usually points to incorrect system time;
see [TIME.md](TIME.md).
