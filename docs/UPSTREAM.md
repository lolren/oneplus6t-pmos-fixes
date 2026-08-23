# Upstream path

## Mobile Broadband Provider database

The standard provider database is the correct first source for carrier APNs,
and NetworkManager already supports it through `gsm.auto-config=yes`.

The `20251101` release installed on the tested phone permits MCC/MNC
`network-id` elements but cannot encode SIM GID. Upstream `main` added a
`<gid1>` element in May 2026, after that release. SMARTY is not yet present.

This was checked on 23 August 2026 against provider-database commit
`515beda0f8ef` and NetworkManager commit `355bc902994f`.

A ready-to-submit provider-data patch is included at:

```text
patches/mobile-broadband-provider-info/0001-gb-add-SMARTY-mobile-provider.patch
```

The patch targets current upstream `main`, uses the new GID field, cites
SMARTY's support page, and passes DTD validation. However, NetworkManager
`main` still matches only MCC/MNC in `nm-service-providers.c`; it does not
consume `<gid1>`. A complete platform fix therefore also needs NetworkManager
to obtain SIM GID1 from ModemManager, include it in provider lookup, and add a
shared-MCC/MNC test.

This repository's helper already parses released or future provider databases
for exact GID1 matches. It sets the matched Internet APN itself because current
NetworkManager auto-configuration would otherwise select the first matching
MCC/MNC provider.

## postmarketOS packaging

The OnePlus 6T is already a community device in pmaports as
`device-oneplus-fajita`. The APN fix should not be hard-coded into that device
package because carrier selection is independent of phone model.

`packaging/APKBUILD` is a local-build recipe for testing the helper as a
standalone no-architecture package. Its README lists the changes required
before an upstream package submission.

## User interface

The original installation displayed a mobile-data notification but did not
create a usable NetworkManager GSM profile. A separate user-interface issue
should include sanitized NetworkManager/ModemManager versions, the absence of a
GSM profile, and the shared-MCC/MNC result. It must not contain SIM serial,
IMSI, IMEI or telephone-number data.
