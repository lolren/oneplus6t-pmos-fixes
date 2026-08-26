#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH_DIR=$ROOT/patches/libcamera/waydroid/v0.7.2
PATCH=$PATCH_DIR/0010-android-route-private-preview-to-rgb.patch

[ -f "$PATCH" ] || {
	printf 'missing RGB preview patch: %s\n' "$PATCH" >&2
	exit 1
}

for previous in \
	0001-android-Enable-mainline-software-ISP-Camera3-HAL.patch \
	0002-android-accelerate-NV12-conversion-with-libyuv.patch \
	0003-android-add-GPU-NV12-software-ISP-path.patch \
	0004-android-make-Waydroid-buffers-and-JPEG-output-robust.patch \
	0005-libcamera-avoid-sigpipe-on-ipa-socket.patch \
	0006-android-reduce-large-preview-source-modes.patch \
	0007-android-avoid-needless-preview-mipmap-generation.patch \
	0008-android-skip-redundant-fullscreen-gpu-clears.patch \
	0009-android-skip-redundant-nv12-gl-finish.patch
do
	[ -f "$PATCH_DIR/$previous" ] || {
		printf 'missing prerequisite patch: %s\n' "$PATCH_DIR/$previous" >&2
		exit 1
	}
done

grep -Fq 'Subject: [PATCH] android: use RGB buffers for private preview streams' \
	"$PATCH"
grep -Fq 'implementationDefinedRgb_' "$PATCH"
grep -Fq 'PostProcessorRgb' "$PATCH"
grep -Fq 'drm_format_' "$PATCH"
grep -Fq 'GRALLOC_USAGE_HW_VIDEO_ENCODER' "$PATCH"
grep -Fq 'formats::XBGR8888' "$PATCH"

# When a patched libcamera tree is supplied, perform the real non-mutating
# application check as an additional CI/release gate. The tree must already
# contain patch 0009; this makes 0010's dependency explicit.
if [ -n "${LIBCAMERA_WAYDROID_SOURCE:-}" ]; then
	git -C "$LIBCAMERA_WAYDROID_SOURCE" apply --check "$PATCH"
fi

printf '%s\n' 'Waydroid RGB private-preview patch tests passed'
