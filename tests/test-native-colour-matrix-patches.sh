#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LIBCAMERA_PATCH=$ROOT/patches/libcamera/v0.7.2/0020-ipa-simple-expose-manual-colour-correction-matrix.patch
MONOLITH=$ROOT/packaging/pmaports/0001-oneplus6t-camera-stack.patch

fail() {
	printf '%s\n' "native colour-matrix patch test: $1" >&2
	exit 1
}

[ -f "$LIBCAMERA_PATCH" ] || fail 'missing libcamera patch'
[ -f "$MONOLITH" ] || fail 'missing pmaports integration patch'

libcamera_blob=0ec442a1e389e4de713e4e5d12dbf6eb606a4b8f
libcamera_sha512=43bb6a94fea96df34b1c97a137d731390d9463b63a49d042196c434666661b1a45eed8ce27b6edb405814e1c8005ad822b976205f5d4fa0088e455ce99c0c5b3
app_sha512=6af7616496de04c98f1eb985fb1beaca509ee506d6bfe79c735e497def95443a04599c8913e8e46787cc5624ce582529e372a753000c2f0d0acb8c9d9caea2a4

test "$(git hash-object "$LIBCAMERA_PATCH")" = "$libcamera_blob" ||
	fail 'libcamera patch blob changed without updating integration'
test "$(sha512sum "$LIBCAMERA_PATCH" | awk '{print $1}')" = "$libcamera_sha512" ||
	fail 'libcamera patch SHA-512 changed without updating recipe'

grep -q 'Subject: \[PATCH 20/20\] ipa: simple: expose manual colour correction matrix' \
	"$LIBCAMERA_PATCH" || fail 'libcamera patch subject is missing'
grep -q 'controls::ColourCorrectionMatrix' "$LIBCAMERA_PATCH" ||
	fail 'patch does not expose ColourCorrectionMatrix'
grep -q 'frameContext.awbAutoEnabled' "$LIBCAMERA_PATCH" ||
	fail 'patch does not gate the manual matrix on white-balance mode'
grep -q 'manualOverride_' "$LIBCAMERA_PATCH" ||
	fail 'patch does not retain the requested manual matrix'
grep -q 'frameContext.ccm' "$LIBCAMERA_PATCH" ||
	fail 'patch does not retain the selected matrix in frame context'
grep -q 'context.activeState.combinedMatrix' "$LIBCAMERA_PATCH" ||
	fail 'patch does not apply the selected matrix to ISP parameters'

grep -Eq "^index 0{7,40}\.\.$libcamera_blob$" "$MONOLITH" ||
	fail 'libcamera patch blob is not embedded in pmaports'
grep -q "^+$libcamera_sha512  0022-ipa-simple-expose-manual-colour-correction-matrix.patch$" \
	"$MONOLITH" || fail 'libcamera patch checksum is not in pmaports'
grep -q "^+$app_sha512  advanced-snapshot-0.1.0-df308e9d95ba9d90ac6866010db3b95ce9d11de4.tar.gz$" "$MONOLITH" ||
	fail 'Advanced Snapshot archive checksum is not in pmaports'
grep -q '^+pkgrel=35$' "$MONOLITH" || fail 'libcamera recipe is not r35'
grep -q '^+pkgrel=36$' "$MONOLITH" || fail 'Advanced Snapshot recipe is not r36'
grep -q '^+_commit="df308e9d95ba9d90ac6866010db3b95ce9d11de4"$' "$MONOLITH" ||
	fail 'Advanced Snapshot source pin is not the tested green-cast preset commit'

printf '%s\n' 'Native colour-matrix patch and pmaports integrity tests passed'
