#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LIBCAMERA_PATCH=$ROOT/patches/libcamera/v0.7.2/0019-ipa-simple-Expose-automatic-and-manual-white-balance.patch
PIPEWIRE_PATCH=$ROOT/patches/pipewire/1.6.8/0002-spa-libcamera-Transport-float-array-controls.patch
MONOLITH=$ROOT/packaging/pmaports/0001-oneplus6t-camera-stack.patch

fail() {
	printf '%s\n' "native white-balance patch test: $1" >&2
	exit 1
}

[ -f "$LIBCAMERA_PATCH" ] || fail 'missing libcamera patch'
[ -f "$PIPEWIRE_PATCH" ] || fail 'missing PipeWire patch'
[ -f "$MONOLITH" ] || fail 'missing pmaports integration patch'

libcamera_blob=6621efd70669bb31abfee773635ade9b5497d923
libcamera_sha512=abb838dd82f87fda3d32f24e0322f62f8619ce6b8200223dc9da570e287bc503e23aecf9fbbd55fb2940224f1791c1b8d513df1f815e967953aadc64b80798c1
pipewire_blob=910b714af9dbadda0f73895e0ef9271819f84ae5
pipewire_sha512=ef273d00a11f8cfc96a5a9933c45d9c53c857f6dfb180e5d4974dd34935e472f70c4948a405429d45445bf13750846f22fca2e25e2c711c081276f3d42f214fa

test "$(git hash-object "$LIBCAMERA_PATCH")" = "$libcamera_blob" ||
	fail 'libcamera patch blob changed without updating integration'
test "$(sha512sum "$LIBCAMERA_PATCH" | awk '{print $1}')" = "$libcamera_sha512" ||
	fail 'libcamera patch SHA-512 changed without updating recipe'
test "$(git hash-object "$PIPEWIRE_PATCH")" = "$pipewire_blob" ||
	fail 'PipeWire patch blob changed without updating integration'
test "$(sha512sum "$PIPEWIRE_PATCH" | awk '{print $1}')" = "$pipewire_sha512" ||
	fail 'PipeWire patch SHA-512 changed without updating recipe'

grep -q 'Subject: \[PATCH\] ipa: simple: Expose automatic and manual white balance' \
	"$LIBCAMERA_PATCH" || fail 'libcamera patch subject is missing'
grep -q 'controls::AwbEnable' "$LIBCAMERA_PATCH" ||
	fail 'libcamera patch does not expose AwbEnable'
grep -q 'controls::ColourGains' "$LIBCAMERA_PATCH" ||
	fail 'libcamera patch does not expose ColourGains'
grep -q 'Subject: \[PATCH\] spa: libcamera: Transport float-array controls' \
	"$PIPEWIRE_PATCH" || fail 'PipeWire patch subject is missing'
grep -q 'ControlTypeFloat' "$PIPEWIRE_PATCH" ||
	fail 'PipeWire patch does not recognize float-array controls'
grep -q 'spa_pod_builder_float' "$PIPEWIRE_PATCH" ||
	fail 'PipeWire patch does not serialize float-array elements'

grep -Eq "^index 0{7,40}\.\.$libcamera_blob$" "$MONOLITH" ||
	fail 'libcamera patch blob is not embedded in pmaports'
grep -q "^+$libcamera_sha512  0021-ipa-simple-Expose-automatic-and-manual-white-balance.patch$" \
	"$MONOLITH" || fail 'libcamera patch checksum is not in pmaports'
grep -Eq "^index 0{7,40}\.\.$pipewire_blob$" "$MONOLITH" ||
	fail 'PipeWire patch blob is not embedded in pmaports'
grep -q "^+$pipewire_sha512  0002-spa-libcamera-Transport-float-array-controls.patch$" \
	"$MONOLITH" || fail 'PipeWire patch checksum is not in pmaports'

grep -q '^+pkgrel=31$' "$MONOLITH" || fail 'libcamera recipe is not r31'
grep -q '^+pkgrel=8$' "$MONOLITH" || fail 'PipeWire recipe is not r8'
grep -q '^+pkgrel=32$' "$MONOLITH" || fail 'Advanced Snapshot recipe is not r32'
grep -q '^+_commit="aa9fea6464c580c308cefecc6383f57c58910102"$' "$MONOLITH" ||
	fail 'Advanced Snapshot source pin is not the tested white-balance commit'

printf '%s\n' 'Native white-balance patch and pmaports integrity tests passed'
