#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH=$ROOT/patches/libcamera/waydroid/v0.7.2/0017-android-wait-on-post-processor-source-fences.patch

[ -f "$PATCH" ] || {
	printf 'missing post-processor fence patch: %s\n' "$PATCH" >&2
	exit 1
}

grep -Fq 'Subject: [PATCH] android: wait on post-processor source fences' \
	"$PATCH"
grep -Fq 'waitPostProcessorSourceFence(FrameBuffer &source)' "$PATCH"
grep -Fq 'std::set<FrameBuffer *> postProcessorSources' "$PATCH"
grep -Fq 'descriptor->pendingStreamsToProcess_' "$PATCH"
grep -Fq 'request->findBuffer(stream->stream())' "$PATCH"
grep -Fq 'constexpr int timeoutMs = 1000' "$PATCH"
grep -Fq 'source.releaseFence()' "$PATCH"
grep -Fq 'buffer.frameBuffer->releaseFence()' "$PATCH"

# Optionally prove application against the exact r49 tree (patches 0001-0016).
# The supplied source is never modified: all checks run in a temporary worktree.
if [ -n "${LIBCAMERA_WAYDROID_R49_SOURCE:-}" ]; then
	revision=${LIBCAMERA_WAYDROID_R49_REVISION:-HEAD}
	check_tree=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-fence-check.XXXXXX")
	cleanup() {
		git -C "$LIBCAMERA_WAYDROID_R49_SOURCE" worktree remove --force \
			"$check_tree" >/dev/null 2>&1 || true
	}
	trap cleanup EXIT HUP INT TERM
	git -C "$LIBCAMERA_WAYDROID_R49_SOURCE" worktree add --detach \
		"$check_tree" "$revision" >/dev/null
	git -C "$check_tree" apply --check "$PATCH"
	git -C "$check_tree" apply "$PATCH"
	git -C "$check_tree" diff --check
	grep -Fq 'waitPostProcessorSourceFence' \
		"$check_tree/src/android/camera_device.cpp"
	cleanup
	trap - EXIT HUP INT TERM
fi

printf '%s\n' 'Waydroid post-processor fence patch tests passed'
