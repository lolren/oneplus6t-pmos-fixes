#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH=$ROOT/patches/libcamera/waydroid/v0.7.2/0016-software_isp-render-contiguous-NV12-in-one-target.patch

[ -f "$PATCH" ] || {
	printf 'missing contiguous NV12 patch: %s\n' "$PATCH" >&2
	exit 1
}

grep -Fq 'Subject: [PATCH] software_isp: render contiguous NV12 in one target' \
	"$PATCH"
grep -Fq 'src/libcamera/shaders/nv12_contiguous.frag' "$PATCH"
grep -Fq 'DRM_FORMAT_GR88' "$PATCH"
grep -Fq 'uvOffset != yOffset + yLength' "$PATCH"
grep -Fq 'yStatus.st_ino == uvStatus.st_ino' "$PATCH"
grep -Fq 'sharpness * (rgb0 - blur0)' "$PATCH"
grep -Fq ') * 0.25;' "$PATCH"
grep -Fq 'Rendering contiguous NV12 with one DMA-BUF target' "$PATCH"
grep -Fq 'using readback conversion' "$PATCH"
grep -Fq 'if (outputIsNv12_ && !nv12RenderedDirect_' "$PATCH"
grep -Fq 'UniqueFD fence = egl_.exportOutputFence();' "$PATCH"

if grep -Eq 'nv12_(y|uv)\.frag' "$PATCH"; then
	printf '%s\n' 'contiguous NV12 patch contains an obsolete plane shader' >&2
	exit 1
fi

# Optionally prove application against the exact r44 tree (patches 0001-0015).
# The supplied source is never modified: all checks run in a temporary worktree.
if [ -n "${LIBCAMERA_WAYDROID_R44_SOURCE:-}" ]; then
	check_tree=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-contiguous-nv12-check.XXXXXX")
	cleanup() {
		git -C "$LIBCAMERA_WAYDROID_R44_SOURCE" worktree remove --force \
			"$check_tree" >/dev/null 2>&1 || true
	}
	trap cleanup EXIT HUP INT TERM
	git -C "$LIBCAMERA_WAYDROID_R44_SOURCE" worktree add --detach \
		"$check_tree" HEAD >/dev/null
	git -C "$check_tree" apply --check "$PATCH"
	git -C "$check_tree" apply "$PATCH"
	git -C "$check_tree" diff --check
	grep -Fq 'nv12_contiguous.frag' \
		"$check_tree/src/libcamera/shaders/meson.build"
	cleanup
	trap - EXIT HUP INT TERM
fi

printf '%s\n' 'Waydroid contiguous NV12 patch tests passed'
