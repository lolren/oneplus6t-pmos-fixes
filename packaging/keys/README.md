# Package verification key

`pmos@local-6a8b0868.rsa.pub` is the current public half of the development
key used to sign new camera-generation APKs. The retained
`pmos@local-6a8d1587.rsa.pub` key verifies older r24/r25 rollback APKs. Publishing
public keys allows package verification; it does not reveal signing capability.

SHA-256:
`31d5d6663ebe400a93fd3d5a107da2ea4dd96e8f6835ba1cdfecf89389ec16f6`

The retained rollback key `pmos@local-6a8d1587.rsa.pub` has SHA-256
`99634ddcfb869f0e5efd73a18743804d5cf03afde9fc50448b445d087aeceed7` and is
used only to verify the older r24/r25 libcamera packages. New indexes and
candidate packages remain signed with the current key above.

Never commit or copy the private `.rsa` key. Before a public VibeMarketOS
repository is released, rotate to a dedicated protected signing key, publish
its fingerprint through an independent channel and document a revocation path.
