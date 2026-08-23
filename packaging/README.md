# Alpine/postmarketOS package staging

`APKBUILD` packages the current checkout as a no-architecture Alpine package.
It is intended for local validation before a recipe is copied into an aports or
pmaports tree.

On an Alpine/postmarketOS build machine with `alpine-sdk` and a configured
abuild key:

```sh
cd packaging
abuild -r
```

The package depends on the current owners of `ip`, `mmcli`, `nmcli` and the
Mobile Broadband Provider database. `curl`, `resolvectl` and systemd time
tools remain optional: diagnostics degrade safely when they are absent, and the
time helper reports an explicit error outside a systemd installation.

Before upstreaming this recipe:

1. replace the local-checkout `builddir` with an immutable release or commit
   archive in `source`;
2. generate and commit its SHA-512 checksum with `abuild checksum`;
3. run `apkbuild-lint`, `pmbootstrap lint` and a clean aarch64 build; and
4. decide whether the scripts belong in a standalone package or an existing
   postmarketOS networking package.

Do not add a carrier-specific SMARTY profile to
`device-oneplus-fajita`. APNs belong to provider data, and the same phone may
use any carrier.
