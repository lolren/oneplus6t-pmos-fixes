# PipeWire libcamera control transport

Apply the patches in this directory to PipeWire 1.6.8 after libcamera has gained
`AfWindows` support. It transports rectangle-array controls through SPA and
publishes crop, orientation and generation-correlated autofocus state as
camera-node properties.

Patch `0002` generalizes the SPA/libcamera value conversion for fixed-size
float arrays. This is required for standard controls such as the two-element
`ColourGains`; it preserves scalar handling and rejects malformed array pods.
The patch does not special-case OnePlus sensors or libcamera numeric IDs.

The crop properties let camera applications map a tap in a letterboxed and
rotated preview to the sensor coordinate system without hard-coding a phone or
camera geometry. Three additional read-only properties make the result
truthful:

- `api.libcamera.af-trigger-generation` increments only when an
  `AfTriggerStart` control is accepted;
- `api.libcamera.af-state-trigger-generation` identifies the trigger attached
  to the completed request; and
- `api.libcamera.af-state` publishes `idle`, `scanning`, `focused` or `failed`
  from that request's libcamera metadata.

The generation is attached to the request carrying the trigger and remains
active for subsequent metadata. This prevents a client from mistaking an old
continuous-focus result for its new tap. A fixed-focus camera with no
`AfState` metadata publishes none of the autofocus-result properties.

Both patches reapplied cleanly to the PipeWire 1.6.8 tag. The reference
aarch64 package build completed all 52 PipeWire tests. The patches only change
`pipewire-spa-libcamera`; applications that do not use libcamera are
unaffected.

- Patch SHA-512:
  `698969b493c84f19c28d4f071ec08fce153ad849008fbf181eb2b055921e9b5081f3211002ed21abf5d1647f26dad975ae4ed2a790c798b938c90ab68f5fedd6`
- Signed r7 APK SHA-256:
  `c6e2f3dc9f27b89dc2ebef448e4242bfa3f40ae2606c146b291e5caa85e612d1`
- Float-array patch SHA-512:
  `ef273d00a11f8cfc96a5a9933c45d9c53c857f6dfb180e5d4974dd34935e472f70c4948a405429d45445bf13750846f22fca2e25e2c711c081276f3d42f214fa`
- Signed r8 `pipewire-spa-libcamera` APK SHA-256:
  `ac9a89ca85e06b17f74ed8968e745f28bf77a4bf94c0fc318012e4d1d52b9d18`

On the installed r6 rollback baseline, a negotiated 640x480 IMX519 stream
published:

```text
api.libcamera.scaler-crop=1368,1042,1920,1440
api.libcamera.scaler-crop-maximum=1048,1042,2560,1440
api.libcamera.stream-orientation=6
```

Those values are stream state, so they are intentionally absent while the node
is idle. The r7 candidate adds the three autofocus-result properties above and
has a clean aarch64 package build. Its device acceptance must show a newly
accepted generation reaching a terminal state on both rear sensors before r7
replaces r6 as the documented baseline. Do not hard-code ephemeral PipeWire
serials used during a test.

The installed r8 candidate retained that focus behavior and exposed
`AwbEnable` plus two-float `ColourGains` on IMX371, IMX376 and IMX519. Extreme
manual gains and automatic restoration were accepted on every active stream.
