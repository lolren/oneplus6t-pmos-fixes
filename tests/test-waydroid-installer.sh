#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER=$ROOT/scripts/install-waydroid-camera
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-installer-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

stage=$TEST_DIR/stage
overlay=$TEST_DIR/overlay
mountinfo=$TEST_DIR/mountinfo
proc_root=$TEST_DIR/proc
mkdir -p "$stage" "$overlay/vendor" "$overlay/system/etc/init" "$proc_root/pressure"

while IFS= read -r target; do
	[ -n "$target" ] || continue
	mkdir -p "$stage/$(dirname "$target")"
	: > "$stage/$target"
done <<'EOF'
vendor/lib/hw/camera.libcamera.so
vendor/lib/libcamera.so
vendor/lib/libcamera-base.so
vendor/lib/libc++_shared.so
vendor/lib/libcamera/ipa/ipa_soft_simple.so
vendor/lib/libcamera/ipa/ipa_soft_simple.so.sign
vendor/libexec/libcamera/soft_ipa_proxy
vendor/etc/libcamera/camera_hal.yaml
vendor/etc/libcamera/configuration.yaml
vendor/share/libcamera/ipa/simple/imx371.yaml
vendor/share/libcamera/ipa/simple/imx376.yaml
vendor/share/libcamera/ipa/simple/imx519.yaml
vendor/share/libcamera/ipa/simple/uncalibrated.yaml
EOF

printf '%s\n' '1 2 0:1 / /var/lib/waydroid/rootfs rw - ext4 /dev/root rw' > "$mountinfo"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	> "$proc_root/pressure/io"
if VIDEO_GID=27 WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/mounted.out" 2> "$TEST_DIR/mounted.err"; then
	printf '%s\n' 'installer did not refuse a mounted Waydroid rootfs' >&2
	exit 1
fi
grep -q 'rootfs is mounted' "$TEST_DIR/mounted.err"

: > "$mountinfo"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	> "$proc_root/pressure/io"
VIDEO_GID=27 WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/clear.out"
grep -q '^dry-run: would back up to ' "$TEST_DIR/clear.out"
grep -q '^dry-run: would install 13 runtime files' "$TEST_DIR/clear.out"

printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=100.00 avg60=100.00 avg300=100.00 total=1' \
	> "$proc_root/pressure/io"
if VIDEO_GID=27 WAYDROID_CAMERA_MOUNTINFO="$mountinfo" \
	WAYDROID_CAMERA_PROC_ROOT="$proc_root" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/pressure.out" 2> "$TEST_DIR/pressure.err"; then
	printf '%s\n' 'installer did not refuse active full I/O pressure' >&2
	exit 1
fi
grep -q 'I/O pressure is active' "$TEST_DIR/pressure.err"

printf '%s\n' 'Waydroid installer mount guard tests passed'
