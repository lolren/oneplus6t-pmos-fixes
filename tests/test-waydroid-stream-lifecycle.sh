#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH=$ROOT/patches/libcamera/waydroid/v0.7.2/0018-android-drain-post-processors-before-stream-reset.patch

[ -f "$PATCH" ] || {
	printf 'missing Android stream-lifecycle patch: %s\n' "$PATCH" >&2
	exit 1
}

grep -Fq 'Subject: [PATCH] android: drain post-processors before stream reset' \
	"$PATCH"
grep -Fq 'for (CameraStream &cameraStream : streams_)' "$PATCH"
grep -Fq 'cameraStream.flush();' "$PATCH"
grep -Fq 'cameraStream.restart();' "$PATCH"
grep -Fq 'void CameraStream::restart()' "$PATCH"
grep -Fq 'wait();' "$PATCH"
grep -Fq 'ASSERT(state_ == State::Stopped);' "$PATCH"
grep -Fq 'std::clamp<int64_t>' "$PATCH"
grep -Fq 'completePendingDescriptors();' "$PATCH"
grep -Fq 'void CameraDevice::completePendingDescriptors()' "$PATCH"
grep -Fq 'std::chrono::steady_clock' "$PATCH"
grep -Fq 'descriptor->sensorTimestamp_' "$PATCH"
grep -Fq 'captureResult.partial_result = 1;' "$PATCH"

# Optionally prove application against a complete patched libcamera tree. The
# supplied source is never modified: all checks run in a temporary worktree.
if [ -n "${LIBCAMERA_WAYDROID_SOURCE:-}" ]; then
	revision=${LIBCAMERA_WAYDROID_REVISION:-HEAD}
	check_tree=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-stream-lifecycle-check.XXXXXX")
	cleanup() {
		git -C "$LIBCAMERA_WAYDROID_SOURCE" worktree remove --force \
			"$check_tree" >/dev/null 2>&1 || true
	}
	trap cleanup EXIT HUP INT TERM
	git -C "$LIBCAMERA_WAYDROID_SOURCE" worktree add --detach \
		"$check_tree" "$revision" >/dev/null
	git -C "$check_tree" apply --check "$PATCH"
	git -C "$check_tree" apply "$PATCH"
	git -C "$check_tree" diff --check
	grep -Fq 'void CameraStream::restart()' \
		"$check_tree/src/android/camera_stream.cpp"
	grep -Fq 'for (CameraStream &cameraStream : streams_)' \
		"$check_tree/src/android/camera_device.cpp"
	grep -Fq 'void CameraDevice::completePendingDescriptors()' \
		"$check_tree/src/android/camera_device.cpp"
	grep -Fq 'std::chrono::steady_clock' \
		"$check_tree/src/android/camera_device.cpp"
	cleanup
	trap - EXIT HUP INT TERM
fi

printf '%s\n' 'Waydroid stream-lifecycle patch tests passed'
