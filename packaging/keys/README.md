# Package verification key

`pmos@local-6a8b0868.rsa.pub` is the public half of the development key used
to sign the six reference camera-generation APKs. Publishing it allows package
verification; it does not reveal signing capability.

SHA-256:
`31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6`

Never commit or copy the private `.rsa` key. Before a public VibeMarketOS
repository is released, rotate to a dedicated protected signing key, publish
its fingerprint through an independent channel and document a revocation path.
