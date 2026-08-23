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

If the standard `mobile-broadband-provider-info` schema can represent the
carrier unambiguously, contribute there upstream instead of duplicating it in
the local overlay. Its current schema cannot distinguish MVNOs by SIM GID, so
this project's overlay covers those cases while retaining safe refusal.
