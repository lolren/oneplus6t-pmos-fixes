#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH=$ROOT/patches/libcamera/waydroid/v0.7.2/0009-android-skip-redundant-nv12-gl-finish.patch
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-gpu-sync-test.XXXXXX")
trap 'rm -rf -- "$TEST_DIR"' EXIT HUP INT TERM

[ -f "$PATCH" ] || {
	printf 'missing GPU sync patch: %s\n' "$PATCH" >&2
	exit 1
}

fixture=$TEST_DIR/src/libcamera/software_isp/debayer_egl.cpp
mkdir -p "$(dirname -- "$fixture")"
{
	printf '%b\n' \
		'void DebayerEGL::process(uint32_t frame, FrameBuffer *input, FrameBuffer *output)' \
		'{' \
		'\t}' \
		'\tinDmaSyncer.reset();' \
		'' \
		'\tegl_.syncOutput();' \
		'\tbench_.finishFrame();' \
		'' \
		'\toutputBufferReady.emit(output);'
} >"$fixture"

git -C "$TEST_DIR" apply --check "$PATCH"
git -C "$TEST_DIR" apply "$PATCH"

grep -Fq 'if (!outputIsNv12_)' "$fixture"
grep -Fq 'egl_.syncOutput();' "$fixture"
if [ "$(grep -c 'syncOutput' "$fixture")" -ne 1 ]; then
	printf '%s\n' 'GPU sync patch left an unconditional glFinish path' >&2
	exit 1
fi

printf '%s\n' 'Waydroid GPU sync patch tests passed'
