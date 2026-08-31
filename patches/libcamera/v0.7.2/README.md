# Native libcamera 0.7.2 patch series

Apply these twenty-one patches in numeric order after pmaports' two simple-pipeline
patches. They add the OnePlus 6T sensor helpers and properties, software-ISP
exposure/focus/image controls, stable rear autofocus, normalized manual focus,
standard automatic/manual white balance and a writable standard colour matrix.

Patch `0019` registers `AwbEnable` and the two-element `ColourGains` control in
the simple IPA. Automatic white balance remains enabled by default. A request
that disables AWB may set red and blue gains from 0 to 4 while green remains
1.0; the applied mode, gains and estimated colour temperature are returned in
request metadata. This follows libcamera's standard white-balance contract and
does not add a proprietary control or hard-code PipeWire property IDs.

Patch `0020` registers the standard nine-element `ColourCorrectionMatrix` and
applies a requested matrix only while automatic white balance is disabled, as
required by libcamera. The manual matrix is retained across requests until AWB
is re-enabled; ordinary manual-white-balance requests without an override keep
the temperature-interpolated tuned matrix. The applied matrix is returned in
request metadata. Patch `0023` additionally exposes verified sensor test-pattern
modes through the simple pipeline, allowing calibration to distinguish
sensor/Bayer errors from scene white-balance errors. The OnePlus downstream
profile package uses a conservative row-sum-preserving matrix on all three
sensors to reduce the measured green excess without changing equal-channel
grey. It is a scene-level correction, not a claim of factory or chart-derived
Android calibration.

The complete series applies cleanly to libcamera v0.7.2. Its nineteen-patch
predecessor passed a clean native GCC Meson suite with 46 passes, one expected
failure, 30 skips and no unexpected failure. The complete profile/test-pattern
build is r33 and contains twenty-one downstream patches.
pmbootstrap AArch64 build produced and installed:

- `libcamera-99990.7.2-r33.apk`, SHA-256
  `76808314599b548a86c2924aaea82b98ce0a913a38967acfd32cd95b54684f6d`;
- `libcamera-ipa-99990.7.2-r33.apk`, SHA-256
  `b54c2ada1f1e2bd833c385247ee796cbd58a40077d7f74646e5d7b5e36c9c89e`.

Patch `0019` has SHA-512
`2c99d73fded811919b02806820a6ac4e82791f0e54ed5a485183049d4d2a0159b6a593f4da379e64285c0376e1dbba34fd5a674fe89f246f901c1f9fbc39d9e1`.
Patch `0020` has SHA-512
`43bb6a94fea96df34b1c97a137d731390d9463b63a49d042196c434666661b1a45eed8ce27b6edb405814e1c8005ad822b976205f5d4fa0088e455ce99c0c5b3`.
Patch `0023` has SHA-512
`7300f9145b164757382cb79c5fb7a21a7758c0b68d59b9f9505c7f0de3559590ca1b0a1d8ba739f83c020414fc03d0dc9818dc6cfe25c50dc9fa4a4d533d22f3`.
The paired PipeWire float-array transport is documented in
`patches/pipewire/1.6.8`.

On the reference phone, all three sensors advertised `AwbEnable`,
`ColourGains` and `ColourCorrectionMatrix`. Deliberately extreme manual gains
visibly changed each live stream, the equal-channel IMX519 test pattern stayed
neutral through the GPU processed path, and re-enabling AWB restored automatic
regulation. This validates control
transport and software-ISP application; it does not provide measured factory
coefficients, a lens-shading table or vendor denoise.
