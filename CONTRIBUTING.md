# Contributing carrier data

Carrier rules affect billing and connectivity, so additions must be narrow and
evidence-backed.

For a new `data/mvno-apns.psv` rule:

1. Prefer the carrier's own current support page or another primary source.
2. Record the SIM MCC/MNC and GID value exposed by ModemManager. Never submit an
   IMSI, ICCID, telephone number, account name or device serial.
3. Use the documented Internet APN, not an MMS-only or IMS APN.
4. Record the documented IP mode and public APN credentials, if any.
5. Add a fixture covering both the intended match and a nearby non-match.
6. Run `make test` and `git diff --check`.

If current `mobile-broadband-provider-info` can represent the carrier with its
`<gid1>` field, contribute there upstream instead of duplicating it in the
local overlay. The tested `20251101` release predates that field, and current
NetworkManager does not consume it, so this helper supports both the new
database field and a reviewed compatibility overlay.
