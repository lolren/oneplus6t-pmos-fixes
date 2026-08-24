# Priority order

Work is intentionally serialized on the reference phone so camera, audio,
location and Android-container failures cannot obscure one another.

1. Complete the native camera stack: install the audited userspace packages,
   validate all three cameras, tap-to-focus, exposure, still resolution and
   detail, retain an exact rollback set, then publish the reproducible patch
   series and evidence.
2. Install Waydroid with Play Store support, then validate that every camera
   exposed to Android opens and captures without destabilizing the native
   camera stack.
3. Establish a reliable native GPS fix and then expose location to Waydroid,
   with separate native and Android-side validation.
4. Package and document the Waydroid and GPS changes, including rollback and
   known limitations, before pushing them.

No bootloader, partition, boot-slot or firmware operation belongs to any of
these stages. A reboot is a separate action and requires explicit approval.
