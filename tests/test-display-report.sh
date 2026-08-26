#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-display
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/display-report-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p \
	"$TEST_DIR/proc" \
	"$TEST_DIR/sys/class/drm/card0-DSI-1" \
	"$TEST_DIR/sys/class/backlight/wled/power"
printf '%s\n' 'console=ttyMSM0,115200 root=/dev/mapper/root' >"$TEST_DIR/proc/cmdline"
printf '%s\n' connected >"$TEST_DIR/sys/class/drm/card0-DSI-1/status"
printf '%s\n' enabled >"$TEST_DIR/sys/class/drm/card0-DSI-1/enabled"
printf '%s\n' 1080x2340 >"$TEST_DIR/sys/class/drm/card0-DSI-1/mode"
printf '%s\n%s\n' 1080x2340 1080x1920 >"$TEST_DIR/sys/class/drm/card0-DSI-1/modes"
printf '%s\n' On >"$TEST_DIR/sys/class/drm/card0-DSI-1/dpms"
printf '%s\n' raw >"$TEST_DIR/sys/class/backlight/wled/type"
printf '%s\n' 400 >"$TEST_DIR/sys/class/backlight/wled/brightness"
printf '%s\n' 400 >"$TEST_DIR/sys/class/backlight/wled/actual_brightness"
printf '%s\n' 2047 >"$TEST_DIR/sys/class/backlight/wled/max_brightness"
printf '%s\n' on >"$TEST_DIR/sys/class/backlight/wled/power/control"

output=$TEST_DIR/report.txt
PMOS_DISPLAY_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_DISPLAY_PROC_ROOT="$TEST_DIR/proc" \
	PMOS_DISPLAY_DMESG="$ROOT/tests/fixtures/display-dmesg" \
	PMOS_DISPLAY_TIMEOUT=1 \
	sh "$REPORT" --output "$output"
grep -Fqx 'connector=card0-DSI-1' "$output"
grep -Fqx 'status=connected ' "$output"
grep -Fqx 'mode=1080x2340 ' "$output"
grep -Fqx 'backlight=wled' "$output"
grep -Fqx 'actual_brightness=400 ' "$output"
grep -Fqx 'display_state=connected-active' "$output"
grep -Fqx 'brightness_control=available' "$output"
grep -Fq 'DRM atomic commit failed' "$output"
grep -Fq 's6e3fc2x01' "$output"

if PMOS_DISPLAY_SYSFS_ROOT="$TEST_DIR/sys" \
	PMOS_DISPLAY_PROC_ROOT="$TEST_DIR/proc" \
	PMOS_DISPLAY_DMESG="$ROOT/tests/fixtures/display-dmesg" \
	sh "$REPORT" --output "$output" >/dev/null 2>&1; then
	printf '%s\n' 'display report unexpectedly overwrote an existing output' >&2
	exit 1
fi

mkdir -p "$TEST_DIR/empty/sys/class" "$TEST_DIR/empty/proc"
empty_output=$TEST_DIR/empty-report.txt
PMOS_DISPLAY_SYSFS_ROOT="$TEST_DIR/empty/sys" \
	PMOS_DISPLAY_PROC_ROOT="$TEST_DIR/empty/proc" \
	PMOS_DISPLAY_DMESG=/missing/dmesg \
	sh "$REPORT" --output "$empty_output"
grep -Fqx 'display_state=no-connectors' "$empty_output"
grep -Fqx 'brightness_control=not-confirmed' "$empty_output"
grep -Fqx 'dmesg=unavailable' "$empty_output"

printf '%s\n' 'display report tests passed'
