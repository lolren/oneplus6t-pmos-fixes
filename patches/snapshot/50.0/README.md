# Snapshot camera controls

Apply this three-patch series in filename order to GNOME Snapshot 50.0:

1. select a bounded full-frame 4:3 mode, up to 2048x1536, for still images
   while retaining the inexpensive preview stream; and
2. add crop- and orientation-aware tap-to-focus using dynamically discovered
   PipeWire/libcamera controls; and
3. show an immediate high-contrast focus reticle and add live Exposure,
   Colour, Contrast, Detail and capture-wide digital Zoom controls.

The focus helper does not contain OnePlus-specific node IDs or control
numbers. It ignores fixed-focus cameras, sends one-shot autofocus mode,
metering window, focus window and start trigger in one update, and restores
continuous autofocus after eight seconds.

The second and third patches require the PipeWire and libcamera patches in this
repository. The third patch coalesces slider movement into one control update,
uses the standard libcamera `ExposureValue`, `Saturation`, `Contrast` and
`Sharpness` controls, and uses Camerabin's normal digital zoom so saved output
matches the preview. It does not expose a false HDR switch.

All three patches reapplied cleanly to Snapshot 50.0 and the exact aarch64 r3
package build passed. With the installed r2 lower layers, the helper accepted
focus/reset on both rear nodes, moved the main physical lens from parked DAC 0
to DAC 400 and rejected the fixed-focus front node. All three nodes negotiated
2048x1536 through PipeWire.

The r3 package and matching exposure-control libcamera package must be upgraded
together. Its visible reticle, sliders and zoom still require on-phone UI and
saved-image acceptance before this candidate is called installed.
