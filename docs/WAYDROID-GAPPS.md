# Waydroid GAPPS and Play Store

This is an optional, non-default image-initialization procedure for the OnePlus 6T
Waydroid setup. It is separate from the camera overlay: the camera bundle
contains no Google software and this repository does not redistribute Google
APK files or system images.

The reference phone now uses the Google-free deployment in
[WAYDROID-VANILLA.md](WAYDROID-VANILLA.md). GAPPS is retained here only for
users who explicitly accept its background services, account requirements and
additional battery cost.

Waydroid supports a GAPPS system type through its initializer. See the
[official Waydroid command-line documentation](https://github.com/waydroid/docs/blob/master/usage/waydroid-command-line-options.md)
for the current command and image-channel options. Image channels can change,
so record the exact image files and hashes used for a reproducible deployment.

## What this verifies

The read-only check-waydroid-gapps helper checks:

- the Android release and advertised ABI list;
- com.google.android.gms (Google Play services);
- com.google.android.gsf (Google Services Framework); and
- com.android.vending (Google Play Store).

It reports gapps=verified only when all three package paths are returned by
Android Package Manager. It does not claim that a Google account can sign in,
that the device is Play Protect certified, or that every Google application
works. The helper never initializes, starts, stops, unmounts or writes
Waydroid.

## Before changing an existing installation

Keep the existing camera bundle tarball, its SHA-256 manifest and the printed
camera-overlay rollback directory. Then collect the read-only health report:

    pmos-check-waydroid-health --status --processes \
      --output /private/path/oneplus6t-waydroid-health-before-gapps.txt

Do not continue while rootfs_mounts is non-zero, either I/O-pressure avg10 is
non-zero, or overlay_precondition is not pass. The camera installer has the
same gate. A mounted or I/O-stalled rootfs can make both image initialization
and overlay backup hang; recover the phone physically before trying again.

If the helper is not installed yet, run it from this checkout:

    ./scripts/check-waydroid-gapps \
      --output /private/path/oneplus6t-waydroid-gapps-before.txt

It is expected to exit non-zero when the current image is Vanilla/FOSS, the
container is stopped, or the package manager cannot answer. That is a
diagnostic result, not an instruction to force initialization.

## Initialize GAPPS

For a new Waydroid installation, use the official GAPPS system type:

    sudo waydroid init -s GAPPS

For an already initialized Vanilla/FOSS installation, -f requests a forced
reinitialization. Treat this as an image change that can replace the system
and vendor image state and invalidate the managed camera overlay:

    waydroid session stop
    sudo waydroid container stop
    sudo waydroid init -f -s GAPPS

Review the initializer output and keep it with the deployment record. Do not
use -f merely to fix a camera or session error; first run the health report and
inspect the Waydroid logs.

If an image provider supplies a verified local image directory, the
initializer also accepts an explicit image path:

    sudo waydroid init -f -i /private/path/verified-waydroid-images

The directory must contain the image layout expected by the Waydroid version
being used. Do not mix a system image from one release with an unrelated
vendor image. Before initialization, record the image version and hashes, for
example:

    waydroid --version
    sha256sum /private/path/verified-waydroid-images/system.img \
      /private/path/verified-waydroid-images/vendor.img

Do not commit those images or Google credentials to Git.

## Verify and restore the camera overlay

Start the container and session using the normal split between root and the
login user:

    sudo waydroid container start
    waydroid session start
    pmos-check-waydroid-gapps \
      --output /private/path/oneplus6t-waydroid-gapps-after.txt

Require gapps=verified before treating Play Store setup as complete. If
Android reports the packages but Play Store still refuses sign-in, follow its
on-screen device-registration or certification flow; that is outside the
postmarketOS camera layer.

An image initialization can remove or invalidate the camera overlay. After
stopping Waydroid, rerun the health gate, extract a fresh camera bundle, and
use the guarded installer:

    waydroid session stop
    sudo waydroid container stop
    pmos-check-waydroid-health --status --processes
    sudo scripts/install-waydroid-camera --dry-run \
      /private/path/waydroid-camera-stage
    sudo scripts/install-waydroid-camera \
      /private/path/waydroid-camera-stage

Start Waydroid again and run the Camera2 probe in full, preview, preview-yuv,
surface and record profiles. The surface profile is important for this phone
because it distinguishes slow Camera3/software-ISP delivery from slow
Android-surface presentation. The record profile exercises Camera2's
`TEMPLATE_RECORD` without invoking an encoder, so it can reveal a
recording-template-specific slowdown before a real video test.

## Reproducibility record

For each GAPPS deployment, retain:

1. the Waydroid version and exact init command;
2. the system/vendor image hashes or provider release identifiers;
3. the before/after health and GAPPS reports;
4. the camera bundle filename, manifest hash and fixes Git revision; and
5. the Camera2 probe result and any Play Store certification outcome.

The current OnePlus 6T product manifest deliberately leaves GAPPS and runtime
camera acceptance device-gated. No GAPPS image has been silently installed by
this project.
