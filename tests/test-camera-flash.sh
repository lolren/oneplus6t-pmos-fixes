#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FLASH=$ROOT/scripts/camera-flash
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/camera-flash-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

LED_ROOT=$TEST_DIR/sys/class/leds
mkdir -p "$LED_ROOT/white:flash" "$LED_ROOT/yellow:flash"
printf '%s\n' 7 >"$LED_ROOT/white:flash/brightness"
printf '%s\n' 3 >"$LED_ROOT/yellow:flash/brightness"

PMOS_FLASH_SYSFS_ROOT="$LED_ROOT" "$FLASH" --probe
status=$(PMOS_FLASH_SYSFS_ROOT="$LED_ROOT" "$FLASH" --status)
printf '%s\n' "$status" | grep -Fqx 'led=white:flash writable=yes brightness=7'
printf '%s\n' "$status" | grep -Fqx 'led=yellow:flash writable=yes brightness=3'

pulse=$(PMOS_FLASH_SYSFS_ROOT="$LED_ROOT" "$FLASH" --pulse --duration-ms 1 --level 32)
printf '%s\n' "$pulse" | grep -Fqx 'flash=on leds=2 duration_ms=1 level=32'
printf '%s\n' "$pulse" | grep -Fqx 'flash=restored'
[ "$(cat "$LED_ROOT/white:flash/brightness")" = 7 ]
[ "$(cat "$LED_ROOT/yellow:flash/brightness")" = 3 ]

PMOS_FLASH_SYSFS_ROOT="$LED_ROOT" "$FLASH" --pulse --duration-ms 5000 --level 32 \
	>"$TEST_DIR/interrupted.out" 2>&1 &
pulse_pid=$!
poll=0
while [ "$(cat "$LED_ROOT/white:flash/brightness")" = 7 ] && [ "$poll" -lt 50 ]; do
	sleep 0.01
	poll=$((poll + 1))
done
[ "$(cat "$LED_ROOT/white:flash/brightness")" = 32 ]
[ "$(cat "$LED_ROOT/yellow:flash/brightness")" = 16 ]
kill -TERM "$pulse_pid"
if wait "$pulse_pid"; then
	printf '%s\n' 'interrupted pulse unexpectedly succeeded' >&2
	exit 1
else
	pulse_status=$?
	[ "$pulse_status" -eq 130 ]
fi
[ "$(cat "$LED_ROOT/white:flash/brightness")" = 7 ]
[ "$(cat "$LED_ROOT/yellow:flash/brightness")" = 3 ]

PMOS_FLASH_SYSFS_ROOT="$LED_ROOT" "$FLASH" --off >/dev/null
[ "$(cat "$LED_ROOT/white:flash/brightness")" = 0 ]
[ "$(cat "$LED_ROOT/yellow:flash/brightness")" = 0 ]

empty_root=$TEST_DIR/empty
mkdir -p "$empty_root"
if PMOS_FLASH_SYSFS_ROOT="$empty_root" "$FLASH" --probe; then
	printf '%s\n' 'probe unexpectedly succeeded without flash LEDs' >&2
	exit 1
fi

printf '%s\n' 'camera flash helper tests passed'
