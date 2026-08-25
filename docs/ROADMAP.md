# Priority order

Work is intentionally serialized on the reference phone so camera, audio,
location and Android-container failures cannot obscure one another.

1. Preserve the completed lower camera layer: r24/r6/r3 is installed, both
   rear focus transitions pass automated hunting tests, and all three native
   and Waydroid sensors capture. Keep this exact stack as a compatibility
   baseline while application work proceeds.
2. Build Advanced Snapshot as a separately named, GPL-compatible Snapshot fork
   with a polished photo/video interface, truthful focus state and only controls
   implemented by the lower stack. The independent package and correlated
   focus-state source now build; native r7/r1 acceptance is the current gate.
   Do not advertise fake HDR, flash behavior or uncalibrated manual values.
3. Create the VibeMarketOS product layer: a small pmaports overlay, signed APK
   repository, versioned Waydroid bundle, known-good manifest, pre-activation
   camera health checks and retained rollback generations. Upstream
   postmarketOS updates may be staged, but camera-critical replacements must
   not activate until the manifest rebases/builds/tests successfully.
4. Broaden Android acceptance: the Waydroid r24 Camera3 lower layer is installed
   and its all-camera YUV/JPEG/private, AF and EV probe passes. Test real camera
   applications and lifecycle transitions, resolve the remaining JPEG-footer
   and close/flush warnings, then add Play Store support.
5. Establish a reliable native GNSS fix and assisted location, then expose
   location to Waydroid. Validate native coordinates and Android applications
   separately so a network-derived fallback cannot be mistaken for GPS.
6. Investigate read-only NFC tag support, audio-route/microphone policy,
   suspend/resume and power use as separate bounded workstreams after camera
   and location acceptance.
7. Keep every accepted change packaged, documented, rollback-safe and pushed
   before moving to the next subsystem.

No bootloader, partition, boot-slot or firmware operation belongs to any of
these stages. A reboot is a separate action and requires explicit approval.
