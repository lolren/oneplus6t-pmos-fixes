#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PREPARER=$ROOT/scripts/prepare-waydroid-camera-provider
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-provider-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/bin"
: > "$TEST_DIR/vendor.img"

cat > "$TEST_DIR/bin/debugfs" <<'EOF'
#!/bin/sh
set -eu
[ "$1" = -R ]
set -- $2
[ "$1" = dump ]
[ "$2" = -p ]
target=$4
printf 'fixture\n' > "$target"
EOF

cat > "$TEST_DIR/bin/readelf" <<'EOF'
#!/bin/sh
cat <<'HEADER'
  Class:                             ELF32
  Data:                              2's complement, little endian
  Machine:                           ARM
HEADER
EOF
chmod 0755 "$TEST_DIR/bin/debugfs" "$TEST_DIR/bin/readelf"

PATH="$TEST_DIR/bin:$PATH" "$PREPARER" \
	"$TEST_DIR/vendor.img" "$TEST_DIR/stage" > "$TEST_DIR/hashes"

for target in \
	vendor/bin/hw/android.hardware.camera.provider@2.4-service \
	vendor/lib/hw/android.hardware.camera.provider@2.4-impl.so \
	vendor/lib/hw/android.hardware.camera.provider@2.4-legacy.so \
	vendor/lib/hw/camera.device@1.0-impl.so
do
	[ -f "$TEST_DIR/stage/$target" ]
	grep -q "  $target$" "$TEST_DIR/hashes"
done

[ "$(stat -c %a "$TEST_DIR/stage/vendor/bin/hw/android.hardware.camera.provider@2.4-service")" = 755 ]
[ "$(stat -c %a "$TEST_DIR/stage/vendor/lib/hw/android.hardware.camera.provider@2.4-impl.so")" = 644 ]

if PATH="$TEST_DIR/bin:$PATH" "$PREPARER" \
	"$TEST_DIR/vendor.img" "$TEST_DIR/stage" >/dev/null 2>&1; then
	printf '%s\n' 'preparer did not refuse a non-empty output directory' >&2
	exit 1
fi

printf '%s\n' 'Waydroid provider preparer tests passed'
