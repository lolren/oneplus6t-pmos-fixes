#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH=$ROOT/patches/libcamera/v0.7.2/0023-libcamera-simple-Expose-sensor-test-pattern.patch
MONOLITH=$ROOT/packaging/pmaports/0001-oneplus6t-camera-stack.patch

fail() {
	printf '%s\n' "native sensor-pattern patch test: $1" >&2
	exit 1
}

[ -f "$PATCH" ] || fail 'missing sensor test-pattern patch'
[ -f "$MONOLITH" ] || fail 'missing pmaports integration patch'

blob=efb018f3925ae0179c8f558dcfefc07cf974e45c
sha512=7300f9145b164757382cb79c5fb7a21a7758c0b68d59b9f9505c7f0de3559590ca1b0a1d8ba739f83c020414fc03d0dc9818dc6cfe25c50dc9fa4a4d533d22f3

test "$(git hash-object "$PATCH")" = "$blob" ||
	fail 'sensor test-pattern patch blob changed without updating integration'
test "$(sha512sum "$PATCH" | awk '{print $1}')" = "$sha512" ||
	fail 'sensor test-pattern patch SHA-512 changed without updating recipe'

grep -q 'controls::draft::TestPatternMode' "$PATCH" ||
	fail 'patch does not expose TestPatternMode'
grep -q 'sensor_->setTestPatternMode' "$PATCH" ||
	fail 'patch does not apply TestPatternMode to the sensor'
grep -Eq "^index 0{7,40}\.\.$blob$" "$MONOLITH" ||
	fail 'sensor test-pattern patch blob is not embedded in pmaports'
grep -q "^+$sha512  0023-libcamera-simple-Expose-sensor-test-pattern.patch$" \
	"$MONOLITH" || fail 'sensor test-pattern checksum is not in pmaports'
grep -q '^+pkgrel=34$' "$MONOLITH" || fail 'libcamera recipe is not r34'

printf '%s\n' 'Native sensor test-pattern patch and pmaports integrity tests passed'
