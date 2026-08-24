# Snapshot camera controls

Apply this two-patch series in filename order to GNOME Snapshot 50.0:

1. select a bounded full-frame 4:3 mode, up to 2048x1536, for still images
   while retaining the inexpensive preview stream; and
2. add crop- and orientation-aware tap-to-focus using dynamically discovered
   PipeWire/libcamera controls.

The focus helper does not contain OnePlus-specific node IDs or control
numbers. It ignores fixed-focus cameras, sends one-shot autofocus mode,
metering window, focus window and start trigger in one update, and restores
continuous autofocus after eight seconds.

The second patch requires the PipeWire and libcamera patches in this
repository. A Snapshot package built without those lower-layer patches may
still run, but tap-to-focus will be rejected and no success indicator will be
shown.

Both patches reapplied cleanly to Snapshot 50.0 and the exact aarch64 r2
package build passed. With the installed lower layers, the helper accepted
focus/reset on both rear nodes, moved the main physical lens from parked DAC 0
to DAC 400 and rejected the fixed-focus front node. All three nodes negotiated
2048x1536 through PipeWire.

The reference phone was locked during unattended validation, so the app
correctly did not keep a camera preview active. A touchscreen tap, marker and
saved 2048x1536 picture remain UI acceptance tests after unlock; lower-layer
focus transport and full-frame caps are already validated.
