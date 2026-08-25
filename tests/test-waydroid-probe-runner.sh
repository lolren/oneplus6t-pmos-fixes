#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNNER=$ROOT/scripts/run-waydroid-camera-probe
TEST_DIR=$(mktemp -d /tmp/waydroid-probe-runner-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/bin"
apk=$TEST_DIR/probe.apk
touch "$apk"

cat >"$TEST_DIR/bin/waydroid" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$*" >> "$WAYDROID_TEST_LOG"
case "$1 $2" in
"app install")
	;;
"shell cat")
	printf '%s\n' \
		'CAMERA id=0 valid=true profile=preview privateFps=24.00' \
		'PROBE_DONE profile=preview valid=1 total=1'
	;;
esac
EOF
chmod 0755 "$TEST_DIR/bin/waydroid"

help_output=$("$RUNNER" --help)
grep -q '^usage: run-waydroid-camera-probe APK' <<EOF
$help_output
EOF

result=$TEST_DIR/result.txt
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$TEST_DIR/waydroid.log" \
	PMOS_WAYDROID_PROBE_TIMEOUT=0 \
	"$RUNNER" "$apk" preview "$result" >"$TEST_DIR/stdout"
grep -q '^result: ' "$TEST_DIR/stdout"
grep -q 'PROBE_DONE profile=preview valid=1 total=1' "$result"
grep -q "app install $apk" "$TEST_DIR/waydroid.log"
grep -q 'shell pm grant dev.lolren.waydroidcameraprobe android.permission.CAMERA' \
	"$TEST_DIR/waydroid.log"
grep -q 'shell am force-stop dev.lolren.waydroidcameraprobe' \
	"$TEST_DIR/waydroid.log"
grep -q 'shell rm -f /data/user/0/dev.lolren.waydroidcameraprobe/files/result.txt' \
	"$TEST_DIR/waydroid.log"
grep -q 'shell am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile preview' \
	"$TEST_DIR/waydroid.log"

if PATH="$TEST_DIR/bin:$PATH" "$RUNNER" "$apk" unsupported \
	>"$TEST_DIR/invalid.out" 2>"$TEST_DIR/invalid.err"; then
	printf '%s\n' 'probe runner accepted an unsupported profile' >&2
	exit 1
fi
grep -q 'unsupported profile: unsupported' "$TEST_DIR/invalid.err"

printf '%s\n' 'Waydroid probe runner tests passed'
