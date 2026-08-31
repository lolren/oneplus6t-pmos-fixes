# Priority order

Work is intentionally serialized on the reference phone so camera, audio,
location and Android-container failures cannot obscure one another.

1. Preserve the live lower camera layer: native libcamera/IPA r35, PipeWire r8
   and Advanced Snapshot r36 are installed, with the exact r34/r36/r8 stage as
   rollback. The r35 matrix is active on all three sensors; rear focus windows
   pass with zero restarts or lens requests and the fixed-focus front passes its
   120-frame stream. Keep this generation as the camera baseline while the
   separately published r37 app-only correction waits for device acceptance.
2. Finish Advanced Snapshot acceptance as a separately named, GPL-compatible
   Snapshot fork with a polished photo/video interface, truthful focus state
   and controls implemented by the lower stack. The r37 source/package and
   offline release gates pass; r36 remains live-installed until the r37
   green-cast Apply/Reset correction can be installed and visually accepted.
   Saved chart/photo, video, HDR and rear-flash acceptance remain.
   Kernel r10 is installed with serialized Samsung brightness writes, bounded
   Venus error recovery and an exact r8 rollback; do not advertise fake HDR,
   flash behavior or uncalibrated manual values.
3. Maintain the VibeMarketOS product layer: the signed r44 runtime, r35/r36
   manifest, offline candidate/rollback repositories, compatibility checks,
   health gates and retained generations are now published. The Advanced
   Snapshot r37 app-only release is published separately and is not activated
   by the default manifest until physical acceptance. Upstream
   postmarketOS updates may be staged, but camera-critical replacements must
   not activate until the manifest rebases/builds/tests successfully. Keep the
   `pmos-safe-upgrade` wrapper and simulation-first managers in the documented
   path.
4. Continue Android acceptance: the Google-free Vanilla image, r53 camera
   provider and r53 Codec2 overlays pass the protected all-camera probes, and
   main/front H.264/AAC files decode without the former colour corruption.
   Main rear remains performance-limited and auxiliary rear hardware encoding
   remains hard-disabled after a reproducible Venus IRQ storm. Soak an
   ordinary Android camera app across open/close and app switching, and keep
   testing only main/front recording. Android computational HDR and vendor
   image-quality parity remain unimplemented.
5. Preserve the reversible GNSS-to-Waydroid bridge. Its read-only polling
   requires advancing NMEA UTC, prioritizes GGA accuracy, restores Android's
   exact app-op/provider state and omits coordinates from applied logs. The
   current phone report still has no GNSS coordinates; repeat outdoors until a
   fresh native fix is obtained, then test a map application. A real Android
   GNSS HAL/A-GPS path remains open.
6. Complete the bounded daily-use checks independently: real modem-call
   microphone/speaker route switching, display brightness/lock/suspend,
   rear-flash restoration, a real NFC tag and matched unplugged battery-drain
   measurements. The read-only reports and rollback paths are implemented;
   these physical acceptance points must not be inferred from fixture tests.
7. Keep every accepted change packaged, documented, rollback-safe and pushed
   before moving to the next subsystem.

No bootloader, raw-flash, boot-slot or firmware operation belongs to these
stages. The exact kernel manager is the sole boot-image exception: its verified
APK transaction runs the normal postmarketOS boot-image trigger. Managers never
reboot automatically; reboot remains a separate acceptance action.
