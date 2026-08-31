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
new per-channel statistics plus highlight constraint form one dependent series;
the configurable `Adjust` defaults are independent. The `AfWindows` work should
follow the autofocus series and gain focused coordinate/window tests. The
software-ISP sharpness control is separately reviewable, with CPU/EGL parity
and endpoint tests included in its submission. Before submission, add focused
upstream unit coverage for histogram quantiles and tuning validation, and
document the two-key backward-compatible AGC schema.

The PipeWire rectangle-array and autofocus-state transport is versioned under
`patches/pipewire/1.6.8/`. It should be proposed only after libcamera's
`AfWindows` semantics are accepted. The `api.libcamera.*` crop, orientation,
state and trigger-generation names are deliberately downstream interfaces,
not a claimed stable PipeWire API. Upstream discussion should decide whether
node properties, control metadata or a typed camera-control/status API is the
right long-term transport before applications depend on unnamespaced keys.

The Snapshot full-frame still patch is independently useful. Tap-to-focus in
`patches/snapshot/50.0/` depends on both lower layers; upstream discussion
should cover whether a small helper process is preferred to native PipeWire
control and status handling in Aperture. Submit measured UI behavior only
after the unlocked touchscreen acceptance test is complete.

The EGL two-pass/mipmap patch should not be proposed unchanged while libcamera's
official multipass GPU-ISP redesign is active; its measured OnePlus result is
useful input to that work, but it needs alignment with the upstream design.
See the official [multipass RFC discussion](https://lists.libcamera.org/pipermail/libcamera-devel/2026-June/059567.html)
and [RGB/Bayer conversion patch](https://lists.libcamera.org/pipermail/libcamera-devel/2026-June/059302.html).

The Waydroid-only contiguous-NV12 patch `0016` is accepted downstream but is
not ready to submit as a generic libcamera interface. Its one-target `GR88`
layout is valid only after proving that Y and UV refer to one linear backing
allocation with the expected offsets and pitch. Any upstream form should be
coordinated with the multipass GPU-ISP work, gain focused DMA-BUF layout tests,
and preserve the current non-contiguous/readback fallback.

Patch `0017` addresses a more general Camera3 correctness boundary: a mapped
post-processor must not consume a GPU-written source until its release fence
signals, and multiple mapped consumers must not race ownership of that fence.
It is a plausible independent upstream candidate rather than part of the
Waydroid-specific `GR88` layout contract. Before submission, add a focused
Camera3 test with a delayed synthetic fence, verify one wait for multiple
consumers, and ask maintainers to review whether fence ownership belongs in
`CameraDevice::requestComplete()` or a lower post-processor abstraction.

Patch `0018` closes the next ownership boundary: `CameraDevice::stop()` drains
the asynchronous YUV/JPEG workers before releasing Camera3 descriptors and
streams, while Android `flush()` drains and restarts workers for configured
stream reuse. It also completes pending descriptors with valid error results
and replaces zero simple-V4L2 timestamps with one monotonic value shared by
the shutter and metadata callbacks. It is a Waydroid Camera3 lifecycle
candidate, not a generic sensor or GPU interface. The source applies, the
Android HAL compiles on the host and the ARM provider passed the diagnostic
reopen/full-probe checks; ordinary third-party-app soak and a focused
framework test remain required before an upstream proposal.

Do not upstream the OnePlus r34 sensor profiles as if they were measured,
generic libcamera calibration. They are downstream numeric interoperability
data and a moderate scene-level green-cast correction deliberately kept in
the OnePlus pmaports overlay. The generic patch series remains valid without
the downstream profiles; the YAML applies the same row-sum-preserving matrix to
the three sensors only for this phone. The values have no chart, illuminant or
flat-field validation and do not include a vendor binary, lens shading or
denoise stage.
The OnePlus gamma/contrast/saturation values are likewise downstream defaults,
not a substitute for a proper camera-calibration submission.

Do not advertise `HdrMode`: sensor WDR registers are not a complete
HDR pipeline without exposure fusion and tone mapping.

Kernel changes should first be reviewed by the SDM845 mainline maintainers,
then routed to Linux media and Qualcomm device-tree maintainers as appropriate.
The pmaports packaging diff is
`packaging/pmaports/0001-oneplus6t-camera-stack.patch`.

Submission evidence may include stable camera IDs, selected modes, bounded
gain/focus metadata, frame rates and sanitized error logs. Do not attach the
user's photographs, raw captures, Android libraries or proprietary tuning
files.
