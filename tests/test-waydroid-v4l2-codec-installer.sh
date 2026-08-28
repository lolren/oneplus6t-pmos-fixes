#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER=$ROOT/scripts/install-waydroid-v4l2-codec
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-codec-installer-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

stage=$TEST_DIR/stage
overlay=$TEST_DIR/overlay
mountinfo=$TEST_DIR/mountinfo
proc_root=$TEST_DIR/proc
mkdir -p "$stage" "$overlay/vendor" "$overlay/system" "$proc_root/pressure"

while IFS= read -r target; do
	mkdir -p "$stage/$(dirname "$target")"
	: > "$stage/$target"
done <<'EOF'
system/bin/hw/android.hardware.media.c2@1.0-service-v4l2-64
system/lib64/libc2plugin_store.so
system/lib64/libv4l2_codec2_common.so
system/lib64/libv4l2_codec2_components.so
system/etc/init/android.hardware.media.c2@1.0-service-v4l2-64.rc
vendor/etc/vintf/manifest/manifest_media_c2_v4l2.xml
vendor/etc/media_codecs_c2.xml
vendor/etc/seccomp_policy/android.hardware.media.c2@1.2-default-seccomp_policy
vendor/etc/seccomp_policy/codec2.vendor.ext.policy
EOF

printf '%s\n' '1 2 0:1 / /var/lib/waydroid/rootfs rw - ext4 /dev/root rw' > "$mountinfo"
printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	> "$proc_root/pressure/io"
if WAYDROID_CODEC_MOUNTINFO="$mountinfo" WAYDROID_CODEC_PROC_ROOT="$proc_root" \
	"$INSTALLER" --dry-run "$stage" "$overlay" \
	> "$TEST_DIR/mounted.out" 2> "$TEST_DIR/mounted.err"; then
	printf '%s\n' 'codec installer did not refuse a mounted Waydroid rootfs' >&2
	exit 1
fi
grep -q 'rootfs is mounted' "$TEST_DIR/mounted.err"

: > "$mountinfo"
WAYDROID_CODEC_MOUNTINFO="$mountinfo" WAYDROID_CODEC_PROC_ROOT="$proc_root" \
	"$INSTALLER" --dry-run "$stage" "$overlay" > "$TEST_DIR/clear.out"
grep -q '^dry-run: would back up to ' "$TEST_DIR/clear.out"
grep -q '^dry-run: would install 9 codec overlay files$' "$TEST_DIR/clear.out"

grep -q 'IComponentStore default' \
	"$ROOT/config/waydroid/v4l2-codec/android.hardware.media.c2@1.0-service-v4l2-64.rc"
grep -q '<instance>default</instance>' \
	"$ROOT/config/waydroid/v4l2-codec/manifest_media_c2_v4l2.xml"
grep -q 'name="c2.v4l2.avc.encoder" type="video/avc" rank="0"' \
	"$ROOT/config/waydroid/v4l2-codec/media_codecs_c2.xml"
if grep -q 'c2.v4l2.*decoder' \
	"$ROOT/config/waydroid/v4l2-codec/media_codecs_c2.xml"; then
	printf '%s\n' 'unvalidated V4L2 decoder leaked into the codec XML' >&2
	exit 1
fi
grep -q '^ioctl: 1$' \
	"$ROOT/config/waydroid/v4l2-codec/android.hardware.media.c2@1.2-default-seccomp_policy"
grep -q '^epoll_pwait: 1$' \
	"$ROOT/config/waydroid/v4l2-codec/codec2.vendor.ext.policy"
grep -q '^sched_getaffinity: 1$' \
	"$ROOT/config/waydroid/v4l2-codec/codec2.vendor.ext.policy"
grep -q '^sched_setscheduler: 1$' \
	"$ROOT/config/waydroid/v4l2-codec/codec2.vendor.ext.policy"

printf '%s\n' \
	'some avg10=0.00 avg60=0.00 avg300=0.00 total=0' \
	'full avg10=7.00 avg60=1.00 avg300=0.10 total=1' \
	> "$proc_root/pressure/io"
if WAYDROID_CODEC_MOUNTINFO="$mountinfo" WAYDROID_CODEC_PROC_ROOT="$proc_root" \
	"$INSTALLER" --dry-run "$stage" "$overlay" \
	> "$TEST_DIR/pressure.out" 2> "$TEST_DIR/pressure.err"; then
	printf '%s\n' 'codec installer did not refuse active I/O pressure' >&2
	exit 1
fi
grep -q 'I/O pressure is active' "$TEST_DIR/pressure.err"

printf '%s\n' 'Waydroid V4L2 Codec2 installer guard tests passed'
