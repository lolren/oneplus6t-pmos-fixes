# Priority order

Work is intentionally serialized on the reference phone so camera, audio,
location and Android-container failures cannot obscure one another.

1. Complete the native camera stack: r22/r6/r3 is installed and its three
   sensors, lower-level controls, exposure and application startup are
   validated. Retain the exact rollback set and finish the unlocked
   touchscreen reticle, sliders, zoom and saved-image acceptance check.
2. Install Waydroid with Play Store support, then validate that every camera
   exposed to Android opens and captures without destabilizing the native
   camera stack.
3. Establish a reliable native GPS fix and then expose location to Waydroid,
   with separate native and Android-side validation.
4. Package and document the Waydroid and GPS changes, including rollback and
   known limitations, before pushing them.

No bootloader, partition, boot-slot or firmware operation belongs to any of
these stages. A reboot is a separate action and requires explicit approval.
