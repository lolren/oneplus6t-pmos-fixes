# Google-free Waydroid

The supported default for this project is a Waydroid LineageOS `VANILLA`
image. It contains no Google Play services, Google Services Framework or Play
Store. Removing those continuously active services reduces background work,
but it does not by itself prove Android-equivalent battery life.

The camera and Codec2 overlays are independent of Google software. They work
on the pinned Vanilla image described here and remain separately rollback-safe.

## Accepted image pair

The reference phone was rebuilt on 2026-08-28 from the official Waydroid ARM64
OTA entries below. The archive identifiers in Waydroid's OTA metadata are the
archive SHA-256 values.

| Image | Official archive SHA-256 | Bytes | Extracted image SHA-256 |
| --- | --- | ---: | --- |
| `lineage-20.0-20260403-VANILLA-waydroid_arm64-system.zip` | `c4b45fad36bee7c0db8a1d9315a5be0035520c53d3d005a807735ae9b7ee79cf` | 904855273 | `e9d0a498105feb5e00895066dee90d738b3961ba334416f26498e357ee966b2e` |
| `lineage-20.0-20260403-MAINLINE-waydroid_arm64-vendor.zip` | `1e6d33d464277ea3964e4658001c8882f21325616d6bcc66d473bc9ee1e246c7` | 147648350 | `b18a05747db565c134db48031caeec3ce4bd9e0ce8f88ef9c679f3ef9e24e39a` |

The authoritative metadata and download URLs are in Waydroid's
[VANILLA system channel](https://ota.waydro.id/system/lineage/waydroid_arm64/VANILLA.json)
and [MAINLINE vendor channel](https://ota.waydro.id/vendor/waydroid_arm64/MAINLINE.json).
Do not assume that the first OTA entry will always have these hashes: select
the named files explicitly and verify both archives before extraction.

## Safe migration from GAPPS

This operation replaces Android system state. Stop Waydroid, retain the
existing `/var/lib/waydroid` directory and the login user's Waydroid data as a
dated rollback, and do not delete that rollback until Vanilla acceptance is
complete. A same-filesystem rename is preferable to deletion and is
recoverable. Never run a broad recursive removal against `/var/lib`, a home
directory or a workspace root.

Download the two named archives to a private staging directory, verify their
sizes and hashes, and extract `system.img` and `vendor.img`. Verify the
extracted hashes from the table, then install only those two regular files in
the custom image directory:

```sh
sudo install -d -m 0755 /etc/waydroid-extra/images
sudo install -m 0644 /private/stage/system.img \
  /etc/waydroid-extra/images/system.img
sudo install -m 0644 /private/stage/vendor.img \
  /etc/waydroid-extra/images/vendor.img
sudo sha256sum /etc/waydroid-extra/images/system.img \
  /etc/waydroid-extra/images/vendor.img
sudo waydroid init -f -s VANILLA -i /etc/waydroid-extra/images
```

Waydroid documents `VANILLA` as its default system type and `-i` as the custom
image path in its
[command-line reference](https://github.com/waydroid/docs/blob/master/usage/waydroid-command-line-options.md).
On the accepted deployment, `waydroid.cfg` records the explicit image path,
`suspend_action = freeze`, and no OTA channels. This intentionally pins the
known-good image pair so an unattended image update cannot silently replace
the camera provider or Codec2 base beneath the overlays.

After initialization, stop Waydroid and install the current complete camera
bundle and r53 Codec2 bundle with their guarded installers. The camera bundle
must be r52 or newer: r51 expected the old image to already provide a 32-bit
legacy camera provider and therefore was not complete on a clean ARM64 Vanilla
installation. The r52 bundle adds the provider service, its implementation
libraries, VINTF manifest and both host `ro.hardware.camera=libcamera`
properties. Its installer backs up all managed overlay targets and both host
property files before writing anything.

## Verification

Start the container and session normally, then run the read-only verifier as
root because `waydroid shell` requires root on postmarketOS:

```sh
sudo pmos-check-waydroid-vanilla
```

Acceptance requires all of these results:

```text
lineage_release_type=VANILLA
package_manager=ready
gms=absent
gsf=absent
play_store=absent
google_gms_property=absent
vanilla=verified
```

The accepted image reports Android 13, security patch `2026-02-01`, build
`eng.aleast.20260403.040932` and the ARM64/ARMv7 ABI list. One LineageOS
compatibility package has the namespace
`com.google.android.apps.googlecamera.fishfood`; its APK is the
`ApertureLensLauncher` shim, not GMS, GSF or Play Store. The verifier checks the
runtime packages that matter rather than rejecting every `com.google` name.

The clean image plus r52 candidate was accepted at the Camera2 boundary:
Android enumerated all three cameras, each delivered preview and displayed
surface frames, the provider remained running, and no kernel, IOMMU, GPU,
camera-provider or Codec2 fatal event appeared. Camera ID 2 remains explicitly
blocked from hardware video encoding because two earlier runs reproduced a
Qualcomm Venus teardown fault; preview and still paths remain available.

## Updates and rollback

Treat every Waydroid image update as a new generation:

1. retain the current images, Android data, camera backup and Codec2 backup;
2. record the proposed archive and extracted-image hashes;
3. initialize the new pair from a private staging directory;
4. reinstall the complete camera and Codec2 bundles;
5. require the Vanilla verifier, all-camera preview/JPEG checks, safe video
   checks for IDs 0/1, audio, cellular, location and orderly-stop health; and
6. keep or roll back the whole generation, never a mixture of unrelated
   system/vendor images.

The old GAPPS tree retained during migration is the rollback source. Restoring
it must be done only with Waydroid stopped and rootfs mounts clear. Do not copy
files into a live or stale-mounted overlay; run
`pmos-check-waydroid-health --status --processes` first.

## Battery behavior

The reference deployment uses `suspend_action = freeze`, and an idle Waydroid
session reaches the frozen-container state. The optional host-to-Waydroid GNSS
bridge remains disabled by default because continuous one-second GNSS polling
is intentionally expensive. Runtime r25 also rate-limits that service and
restores every ModemManager location setting on exit, preventing a bad Android
app-op response from becoming a five-second restart loop.

Use [POWER.md](POWER.md) for the reversible battery suspend policy and an
unplugged measurement. Google-free status, a frozen container and an idle CPU
are prerequisites; they are not a substitute for measured screen-off drain.
