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

The reported Chatty launch failure is not ready for upstream submission. Both
its GApplication and packaged desktop-file activation paths currently create a
window in under 0.3 seconds, and the user confirmed touchscreen launch. See
`MESSAGES.md` for the separate Phoc/DRM presentation evidence. Do not submit a
Chatty issue unless a future recurrence first proves whether the window is
absent or merely not presented.

## Camera stack

Split submissions by ownership and maturity:

- kernel `0001` adds the IMX371 binned mode;
- kernel `0002` adds its OnePlus 6/6T device-tree link frequency;
- kernel `0003` and `0004` correct IMX371/IMX376 analogue-gain ranges;
- kernel `0005` keeps IMX519 high-speed capability but changes ordinary
  preview defaults to 30 fps;
- the existing `patches/libcamera/upstream/0001-*` is the small IMX371 helper
  candidate; and
- `patches/libcamera/v0.7.2/` contains the complete version-specific stack
  used by current postmarketOS.

The sensor helpers, sensor-delay properties, configurable AGC target, focus
statistic and autofocus can be reviewed as independent libcamera changes. The
EGL two-pass/mipmap patch should not be proposed unchanged while libcamera's
official multipass GPU-ISP redesign is active; its measured OnePlus result is
useful input to that work, but it needs alignment with the upstream design.
See the official [multipass RFC discussion](https://lists.libcamera.org/pipermail/libcamera-devel/2026-June/059567.html)
and [RGB/Bayer conversion patch](https://lists.libcamera.org/pipermail/libcamera-devel/2026-June/059302.html).

Do not upstream identity matrices as calibrated sensor tuning. They exist only
to expose the generic saturation control and are explicitly uncalibrated.
Likewise, do not advertise `HdrMode`: sensor WDR registers are not a complete
HDR pipeline without exposure fusion and tone mapping.

Kernel changes should first be reviewed by the SDM845 mainline maintainers,
then routed to Linux media and Qualcomm device-tree maintainers as appropriate.
The pmaports packaging diff is
`packaging/pmaports/0001-oneplus6t-camera-stack.patch`.

Submission evidence may include stable camera IDs, selected modes, bounded
gain/focus metadata, frame rates and sanitized error logs. Do not attach the
user's photographs, raw captures, Android libraries or proprietary tuning
files.
