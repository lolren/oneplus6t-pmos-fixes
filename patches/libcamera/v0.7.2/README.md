# Native libcamera 0.7.2 patch series

Apply these nineteen patches in numeric order after pmaports' two simple-pipeline
patches. They add the OnePlus 6T sensor helpers and properties, software-ISP
exposure/focus/image controls, stable rear autofocus, normalized manual focus,
and standard automatic/manual white balance.

Patch `0019` registers `AwbEnable` and the two-element `ColourGains` control in
the simple IPA. Automatic white balance remains enabled by default. A request
that disables AWB may set red and blue gains from 0 to 4 while green remains
1.0; the applied mode, gains and estimated colour temperature are returned in
request metadata. This follows libcamera's standard white-balance contract and
does not add a proprietary control or hard-code PipeWire property IDs.

The complete series applies cleanly to libcamera v0.7.2. A clean native GCC
build passed libcamera's Meson suite with 46 passes, one expected failure, 30
skips and no unexpected failure. The matching clean pmbootstrap AArch64 build
produced and installed:

- `libcamera-99990.7.2-r29.apk`, SHA-256
  `eec79f739f4b6d702f02a4f0b977c9d67a22a0280b46bdc0a813abf782f2389d`;
- `libcamera-ipa-99990.7.2-r29.apk`, SHA-256
  `ab98208181a36165be34f2547c3239366bf6dd6e64eaf11b320ff02f08e25b0b`.

Patch `0019` has SHA-512
`abb838dd82f87fda3d32f24e0322f62f8619ce6b8200223dc9da570e287bc503e23aecf9fbbd55fb2940224f1791c1b8d513df1f815e967953aadc64b80798c1`.
The paired PipeWire float-array transport is documented in
`patches/pipewire/1.6.8`.

On the reference phone, all three sensors advertised `AwbEnable` and
`ColourGains`. Deliberately extreme manual gains visibly changed each live
stream in the expected direction, and re-enabling AWB restored automatic
regulation. This validates control transport and software-ISP application; it
does not provide a calibrated CCM, lens-shading table or vendor denoise.
