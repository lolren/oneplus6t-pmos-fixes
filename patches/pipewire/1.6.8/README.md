# PipeWire libcamera control transport

Apply the patch in this directory to PipeWire 1.6.8 after libcamera has gained
`AfWindows` support. It transports rectangle-array controls through SPA and
publishes the maximum sensor crop, the effective stream crop and stream
orientation as camera-node properties.

Those properties let camera applications map a tap in a letterboxed and
rotated preview to the sensor coordinate system without hard-coding a phone or
camera geometry.

The patch reapplied cleanly to the PipeWire 1.6.8 tag. The reference aarch64
package build completed all 52 PipeWire tests. The patch only changes
`pipewire-spa-libcamera`; applications that do not use libcamera are
unaffected.

On the installed r6 plugin, a negotiated 640x480 IMX519 stream published:

```text
api.libcamera.scaler-crop=1368,1042,1920,1440
api.libcamera.scaler-crop-maximum=1048,1042,2560,1440
api.libcamera.stream-orientation=6
```

Those values are stream state, so they are intentionally absent while the
node is idle. Both rear nodes accepted the Snapshot focus/reset control path;
the fixed-focus front node rejected it. Do not hard-code the ephemeral
PipeWire serials used during a test.
