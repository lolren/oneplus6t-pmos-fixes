#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PREPARE=$ROOT/scripts/prepare-waydroid-v4l2-codec-sources
BUILD=$ROOT/scripts/build-waydroid-v4l2-codec
PACKAGE=$ROOT/scripts/package-waydroid-v4l2-codec
BASE_PATCH=$ROOT/patches/android-v4l2-codec2/0001-support-qualcomm-venus-single-plane-io.patch
LAYOUT_PATCH=$ROOT/patches/android-v4l2-codec2/0002-preserve-venus-input-layout-and-DMA-lifetime.patch
STRIDE_PATCH=$ROOT/patches/android-v4l2-codec2/0003-read-temporary-graphic-stride-from-metadata.patch
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-codec-build-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

for revision in \
	6cf3be6acb0e321459172ec12824f448e1c14b9e \
	95be9bad234d69f4a8ded5ee72b60315b1353098 \
	8e5f454713fd4d6dfed8975c024a6629a2e859d4 \
	d79ad875113d34c9665a65b8a33dcf7a4fb7dcf1 \
	8c308539d804a6efb2272e4c9e73407241966f34 \
	a75d76fe6c05f26030424f2aaad38469e3bd1f21 \
	e92509cceadc87dee6725b363eb72bf7431ed5da
do
	grep -q "$revision" "$PREPARE"
done

grep -q 'V4L2_MEMORY_MMAP' "$BASE_PATCH"
grep -q 'CPU_READ | C2MemoryUsage::CPU_WRITE' "$BASE_PATCH"
grep -q 'mV4l2Buffer.memory = memory' "$BASE_PATCH"
grep -q 'deviceUV.mOffset' "$LAYOUT_PATCH"
grep -q 'mEncoder.reset();' "$LAYOUT_PATCH"
encoder_reset_line=$(grep -n 'mEncoder.reset();' "$LAYOUT_PATCH" | tail -n1 | cut -d: -f1)
converter_reset_line=$(grep -n 'mInputFormatConverter.reset();' "$LAYOUT_PATCH" | tail -n1 | cut -d: -f1)
[ "$encoder_reset_line" -lt "$converter_reset_line" ]
grep -q '^+.*_UnwrapNativeCodec2GrallocMetadata' "$STRIDE_PATCH"
grep -q 'does not import it into the graphics mapper' "$STRIDE_PATCH"
grep -q '^+.*return stride;' "$STRIDE_PATCH"
grep -q -- '-ffile-prefix-map=' "$BUILD"
grep -q 'Wl,--no-undefined' "$BUILD"
grep -q 'Machine:.*AArch64' "$BUILD"

stage=$TEST_DIR/stage
mkdir -p "$stage"
while IFS= read -r target; do
	mkdir -p "$stage/$(dirname "$target")"
	printf '%s\n' "$target" >"$stage/$target"
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

output_prefix=$TEST_DIR/codec
"$PACKAGE" "$stage" "$output_prefix" >"$TEST_DIR/package.out"
[ -f "$output_prefix.tar.gz" ]
[ -f "$output_prefix.sha256" ]
[ "$(tar -tzf "$output_prefix.tar.gz" | wc -l | tr -d ' ')" -eq 9 ]
(cd "$stage"; sha256sum -c "$output_prefix.sha256") >"$TEST_DIR/check.out"
second_prefix=$TEST_DIR/codec-second
"$PACKAGE" "$stage" "$second_prefix" >"$TEST_DIR/package-second.out"
cmp "$output_prefix.tar.gz" "$second_prefix.tar.gz"
cmp "$output_prefix.sha256" "$second_prefix.sha256"
if "$PACKAGE" "$stage" "$output_prefix" \
	>"$TEST_DIR/repeat.out" 2>"$TEST_DIR/repeat.err"; then
	printf '%s\n' 'codec packager overwrote an existing package' >&2
	exit 1
fi
grep -q 'Refusing to overwrite' "$TEST_DIR/repeat.err"

install_stage=$TEST_DIR/install
make -s -C "$ROOT" install DESTDIR="$install_stage" PREFIX=/usr >/dev/null
for installed in \
	usr/libexec/oneplus6t-pmos-fixes/scripts/prepare-waydroid-v4l2-codec-sources \
	usr/libexec/oneplus6t-pmos-fixes/scripts/build-waydroid-v4l2-codec \
	usr/libexec/oneplus6t-pmos-fixes/scripts/package-waydroid-v4l2-codec \
	usr/libexec/oneplus6t-pmos-fixes/scripts/install-waydroid-v4l2-codec \
	usr/libexec/oneplus6t-pmos-fixes/patches/android-v4l2-codec2/0001-support-qualcomm-venus-single-plane-io.patch \
	usr/libexec/oneplus6t-pmos-fixes/patches/android-v4l2-codec2/0002-preserve-venus-input-layout-and-DMA-lifetime.patch \
	usr/libexec/oneplus6t-pmos-fixes/patches/android-v4l2-codec2/0003-read-temporary-graphic-stride-from-metadata.patch
do
	[ -f "$install_stage/$installed" ]
done

printf '%s\n' 'Waydroid V4L2 Codec2 build and package tests passed'
