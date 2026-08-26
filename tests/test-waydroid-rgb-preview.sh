#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH_DIR=$ROOT/patches/libcamera/waydroid/v0.7.2
PATCH=$PATCH_DIR/0010-android-route-private-preview-to-rgb.patch
FENCE_PATCH=$PATCH_DIR/0011-android-export-native-rgb-fence.patch

[ -f "$PATCH" ] || {
	printf 'missing RGB preview patch: %s\n' "$PATCH" >&2
	exit 1
}

[ -f "$FENCE_PATCH" ] || {
	printf 'missing RGB release-fence patch: %s\n' "$FENCE_PATCH" >&2
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
	0009-android-skip-redundant-nv12-gl-finish.patch \
	0010-android-route-private-preview-to-rgb.patch
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
grep -Fq 'Subject: [PATCH] android: export native fences for RGB preview' \
	"$FENCE_PATCH"
grep -Fq 'exportOutputFence' "$FENCE_PATCH"
grep -Fq 'EGL_SYNC_NATIVE_FENCE_ANDROID' "$FENCE_PATCH"
grep -Fq 'waitSourceFence' "$FENCE_PATCH"
grep -Fq 'setFence' "$FENCE_PATCH"

# When a patched libcamera tree is supplied, perform the real application
# checks in a temporary worktree. The supplied tree must already contain
# patch 0009; both candidate patches are applied only to the temporary copy.
if [ -n "${LIBCAMERA_WAYDROID_SOURCE:-}" ]; then
	check_tree=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-rgb-series-check.XXXXXX")
	cleanup() {
		git -C "$LIBCAMERA_WAYDROID_SOURCE" worktree remove --force \
			"$check_tree" >/dev/null 2>&1 || true
	}
	trap cleanup EXIT HUP INT TERM
	git -C "$LIBCAMERA_WAYDROID_SOURCE" worktree add --detach \
		"$check_tree" HEAD >/dev/null
	git -C "$check_tree" apply --check "$PATCH"
	git -C "$check_tree" apply "$PATCH"
	git -C "$check_tree" apply --check "$FENCE_PATCH"
	git -C "$check_tree" apply "$FENCE_PATCH"
	git -C "$check_tree" diff --check
	cleanup
	trap - EXIT HUP INT TERM
fi

printf '%s\n' 'Waydroid RGB private-preview patch tests passed'
