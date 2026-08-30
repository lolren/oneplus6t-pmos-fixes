# Native libcamera 0.7.2 patch series

Apply these twenty patches in numeric order after pmaports' two simple-pipeline
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
request metadata. Identity is the safe default because no factory or
chart-derived coefficients are shipped.

The complete series applies cleanly to libcamera v0.7.2. Its nineteen-patch
predecessor passed a clean native GCC Meson suite with 46 passes, one expected
failure, 30 skips and no unexpected failure. The complete twenty-patch
pmbootstrap AArch64 build produced and installed:

- `libcamera-99990.7.2-r30.apk`, SHA-256
  `02617ef50c66d0e6c19d78a8dafe18491ac6b5131f7912282ec90d18ea5dc39f`;
- `libcamera-ipa-99990.7.2-r30.apk`, SHA-256
  `d6b4ff5875fbd465c73c42323dc4876e92eea7abece04aa164476ee2ed30e1d2`.

Patch `0019` has SHA-512
`abb838dd82f87fda3d32f24e0322f62f8619ce6b8200223dc9da570e287bc503e23aecf9fbbd55fb2940224f1791c1b8d513df1f815e967953aadc64b80798c1`.
Patch `0020` has SHA-512
`43bb6a94fea96df34b1c97a137d731390d9463b63a49d042196c434666661b1a45eed8ce27b6edb405814e1c8005ad822b976205f5d4fa0088e455ce99c0c5b3`.
The paired PipeWire float-array transport is documented in
`patches/pipewire/1.6.8`.

On the reference phone, all three sensors advertised `AwbEnable`,
`ColourGains` and `ColourCorrectionMatrix`. Deliberately extreme manual gains
visibly changed each live stream, identity/custom matrices were accepted and
re-enabling AWB restored automatic regulation. This validates control
transport and software-ISP application; it does not provide measured factory
coefficients, a lens-shading table or vendor denoise.
