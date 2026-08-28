# Priority order

Work is intentionally serialized on the reference phone so camera, audio,
location and Android-container failures cannot obscure one another.

1. Preserve the completed lower camera layer: native r24/r7/r3 plus Advanced
   Snapshot r1 is installed, and the Waydroid r35 GPU/JPEG bundle is validated.
   Both rear focus transitions pass automated hunting tests, and all three
   native and Waydroid sensors capture. Keep this exact stack as a compatibility
   baseline while application work proceeds.
2. Build Advanced Snapshot as a separately named, GPL-compatible Snapshot fork
   with a polished photo/video interface, truthful focus state and only controls
   implemented by the lower stack. The independent package and correlated
   focus-state source passed native r7/r1 acceptance; visual photo/video,
   control-surface and lifecycle acceptance are the current gates. The
   read-only display/brightness report is packaged alongside this work, and a
   serialized Samsung panel-brightness kernel r9 candidate with an r8 rollback
   is now published for guarded physical testing after recovery. Do not
   advertise fake HDR, flash behavior or uncalibrated manual values.
3. Create the VibeMarketOS product layer: a small pmaports overlay, signed APK
   repository, versioned Waydroid bundle, known-good manifest, pre-activation
   camera health checks and retained rollback generations. Upstream
   postmarketOS updates may be staged, but camera-critical replacements must
   not activate until the manifest rebases/builds/tests successfully. The first
   immutable r7/r1 manifest, simulation-first generation manager and native
   health gate now pass. The `pmos-safe-upgrade` wrapper now intercepts ordinary
   critical-package upgrades; repository signing, compatibility-gated published
   generations and retained public rollback generations remain.
4. Broaden Android acceptance: installed camera r44 retains the NV12 colour
   fix, keeps a linear RGB preview, coalesces NV12 consumers and caps private
   preview size. Live Codec2 r50 drives Venus and saves 1280x720 H.264/AAC at
   exactly 18 fps instead of the software path's 11.37 fps. The pinned r51
   source, clean build and deterministic archive are ready; after a physical
   reboot clears the current D-state Waydroid teardown, install that exact
   archive and repeat illuminated rear, front/auxiliary, long-recording and
   suspend/resume tests. Android computational HDR and vendor image-quality
   parity remain unimplemented.
5. Establish a reliable native GNSS fix and assisted location, then expose
   location to Waydroid. The reproducible dry-run-first NMEA/test-provider
   bridge, optional disabled systemd service and read-only native location
   report now exist. The current Reading result is not accepted as GPS while
   the phone is actually near Stroud; validate fresh native satellite
   coordinates and Android applications separately so network/account/IP
   fallback cannot be mistaken for GNSS.
6. Investigate read-only NFC tag support, audio-route/microphone policy,
   suspend/resume and power use as separate bounded workstreams after camera
   and location acceptance. The reproducible NFC readiness report is now
   available; controller and real-tag acceptance remain device-gated.
7. Keep every accepted change packaged, documented, rollback-safe and pushed
   before moving to the next subsystem.

No bootloader, partition, boot-slot or firmware operation belongs to any of
these stages. The managers never reboot automatically; a reboot is a separate
manual acceptance action after reviewing the evidence.
