#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
COMPARE=$ROOT/scripts/compare-waydroid-camera-probes
TEST_DIR=$(mktemp -d /tmp/waydroid-probe-compare-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

printf '%s\n' \
       'CAMERA id=0 valid=true profile=preview privateFps=8.00 privateIntervalMs=125.00 privateTimingSource=imagereader surfacePixels=not-requested' \
       'CAMERA id=2 valid=true profile=preview privateFps=10.00 privateIntervalMs=100.00 privateTimingSource=imagereader surfacePixels=not-requested' \
       'PROBE_DONE profile=preview valid=2 total=2' \
       >"$TEST_DIR/baseline.txt"

printf '%s\n' \
       'CAMERA id=0 valid=true profile=preview privateFps=16.00 privateIntervalMs=62.50 privateTimingSource=imagereader surfacePixels=not-requested' \
       'CAMERA id=2 valid=true profile=preview privateFps=15.00 privateIntervalMs=66.67 privateTimingSource=imagereader surfacePixels=not-requested' \
       'PROBE_DONE profile=preview valid=2 total=2' \
       >"$TEST_DIR/candidate.txt"

output=$($COMPARE "$TEST_DIR/baseline.txt" "$TEST_DIR/candidate.txt")
printf '%s\n' "$output" | grep -q '^camera=0 .*fps_delta_percent=100.0 '
printf '%s\n' "$output" | grep -q '^camera=2 .*fps_delta_percent=50.0 '
printf '%s\n' "$output" | grep -q '^result=pass '

printf '%s\n' \
       'CAMERA id=0 valid=false profile=preview privateFps=1.00 privateIntervalMs=1000.00 privateTimingSource=imagereader surfacePixels=not-requested' \
       'PROBE_DONE profile=preview valid=0 total=1' \
       >"$TEST_DIR/bad-candidate.txt"
if $COMPARE "$TEST_DIR/baseline.txt" "$TEST_DIR/bad-candidate.txt" \
       >"$TEST_DIR/bad-output"; then
	printf '%s\n' 'invalid candidate unexpectedly passed' >&2
	exit 1
fi
grep -q '^result=fail ' "$TEST_DIR/bad-output"

printf '%s\n' 'Waydroid probe comparison tests passed'
