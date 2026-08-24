# Priority order

Work is intentionally serialized on the reference phone so camera, audio,
location and Android-container failures cannot obscure one another.

1. Finish native camera behavior and UI: r23/r6/r3 is installed and all three
   sensors, timing and lower-level controls capture successfully. Diagnose the
   observed rear continuous-AF hunting, then complete prolonged stable/change
   scene tests and expand the Snapshot controls without advertising fake HDR or
   uncalibrated manual values.
2. Broaden Android acceptance: the Waydroid r23 Camera3 lower layer is installed
   and its all-camera YUV/JPEG/private, AF and EV probe passes. Test real camera
   applications and lifecycle transitions, resolve the remaining JPEG-footer
   and close/flush warnings, then add Play Store support.
3. Establish a reliable native GNSS fix and assisted location, then expose
   location to Waydroid. Validate native coordinates and Android applications
   separately so a network-derived fallback cannot be mistaken for GPS.
4. Investigate read-only NFC tag support, audio-route/microphone policy,
   suspend/resume and power use as separate bounded workstreams after camera
   and location acceptance.
5. Keep every accepted change packaged, documented, rollback-safe and pushed
   before moving to the next subsystem.

No bootloader, partition, boot-slot or firmware operation belongs to any of
these stages. A reboot is a separate action and requires explicit approval.
