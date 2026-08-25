#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-waydroid-health
TEST_DIR=$(mktemp -d /tmp/waydroid-health-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/proc/self" "$TEST_DIR/proc/pressure"
printf '%s\n' '0.10 0.20 0.30 1/100 1234' >"$TEST_DIR/proc/loadavg"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	>"$TEST_DIR/proc/pressure/io"
: >"$TEST_DIR/proc/self/mountinfo"

safe_output=$TEST_DIR/safe.txt
PMOS_WAYDROID_PROC_ROOT="$TEST_DIR/proc" \
	PMOS_WAYDROID_ROOTFS=/var/lib/waydroid/rootfs \
	PMOS_WAYDROID_MOUNTINFO="$TEST_DIR/proc/self/mountinfo" \
	PMOS_WAYDROID_STATUS_CMD="$ROOT/tests/fixtures/waydroid-status" \
	"$REPORT" --status --output "$safe_output"
grep -Fqx 'rootfs_mounts=0' "$safe_output"
grep -Fqx 'io_some_avg10=0.00' "$safe_output"
grep -Fqx 'overlay_precondition=pass' "$safe_output"
grep -Fqx 'Session: STOPPED' "$safe_output"

printf '%s\n' \
	'36 25 0:32 / /var/lib/waydroid/rootfs rw,relatime - tmpfs tmpfs rw' \
	>"$TEST_DIR/proc/self/mountinfo"
printf '%s\n' \
	'some avg10=100.00 avg60=100.00 avg300=100.00 total=1' \
	>"$TEST_DIR/proc/pressure/io"
blocked_output=$TEST_DIR/blocked.txt
PMOS_WAYDROID_PROC_ROOT="$TEST_DIR/proc" \
	PMOS_WAYDROID_ROOTFS=/var/lib/waydroid/rootfs \
	PMOS_WAYDROID_MOUNTINFO="$TEST_DIR/proc/self/mountinfo" \
	"$REPORT" --output "$blocked_output"
grep -Fqx 'rootfs_mounts=1' "$blocked_output"
grep -Fqx 'overlay_precondition=blocked-rootfs-mounted' "$blocked_output"

printf '%s\n' 'waydroid health tests passed'
