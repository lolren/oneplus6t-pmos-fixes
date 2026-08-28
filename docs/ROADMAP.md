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
   read-only display/brightness report is packaged alongside this work. Kernel
   r10 is installed with serialized Samsung brightness writes, bounded Venus
   error recovery and an exact r8 rollback; brightness-specific acceptance is
   still pending. Do not
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
   preview size. Codec2 r53 is reproducibly built, installed and passes three
   guarded rear record/finalize lifecycles without the former green band,
   gralloc crash or Venus teardown fault. The illuminated file averages only
   11.62 fps, so profile that path next, then repeat front/auxiliary,
   long-recording, app-switching and suspend/resume tests. Android computational
   HDR and vendor image-quality parity remain unimplemented.
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

No bootloader, raw-flash, boot-slot or firmware operation belongs to these
stages. The exact kernel manager is the sole boot-image exception: its verified
APK transaction runs the normal postmarketOS boot-image trigger. Managers never
reboot automatically; reboot remains a separate acceptance action.
