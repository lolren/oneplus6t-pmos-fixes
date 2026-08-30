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
request metadata. Identity remains the safe generic default in this patch
series. The OnePlus downstream r31 pmaports recipe supplies separate sensor
YAML profiles; those are numeric stock-derived interoperability data, not
factory or chart-derived calibration and not part of an upstream patch
submission.

The complete series applies cleanly to libcamera v0.7.2. Its nineteen-patch
predecessor passed a clean native GCC Meson suite with 46 passes, one expected
failure, 30 skips and no unexpected failure. The complete twenty-patch
pmbootstrap AArch64 build produced and installed:

- `libcamera-99990.7.2-r31.apk`, SHA-256
  `573b24e1249e2e2a91731dfd5fe57949e966e48ca2f3a2a4e5ff128c71dc4038`;
- `libcamera-ipa-99990.7.2-r31.apk`, SHA-256
  `f04b0ab0c147129484d6ae8c57bac6c4f49fa35513f581d2b2ab0214dffeafaf`.

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
