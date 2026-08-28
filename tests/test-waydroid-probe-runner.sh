#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNNER=$ROOT/scripts/run-waydroid-camera-probe
PROBE_SOURCE=$ROOT/tests/waydroid-camera-probe/src/dev/lolren/waydroidcameraprobe/CameraProbeActivity.java

grep -q 'map.getOutputSizes(SurfaceTexture.class)' "$PROBE_SOURCE"
grep -q 'privateSizes = map.getOutputSizes(ImageFormat.YUV_420_888)' \
	"$PROBE_SOURCE"
grep -q 'size.getWidth() == 1280 && size.getHeight() == 960' "$PROBE_SOURCE"
grep -q 'PROFILE_RECORD_YUV_720P = "record-yuv-720p"' "$PROBE_SOURCE"
grep -q 'size.getWidth() == 1280 && size.getHeight() == 720' "$PROBE_SOURCE"
grep -q 'CaptureResult.SENSOR_TIMESTAMP' "$PROBE_SOURCE"
grep -q 'captureFps=' "$PROBE_SOURCE"
TEST_DIR=$(mktemp -d /tmp/waydroid-probe-runner-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

grep -q 'CameraDevice.TEMPLATE_RECORD' "$PROBE_SOURCE"
grep -q 'chooseRecordFpsRange' "$PROBE_SOURCE"
grep -q 'surfaceSamplePending.compareAndSet(false, true)' "$PROBE_SOURCE"

mkdir -p "$TEST_DIR/bin"
apk=$TEST_DIR/probe.apk
printf '%s\n' 'fixture apk' >"$apk"

cat >"$TEST_DIR/bin/waydroid" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$*" >> "$WAYDROID_TEST_LOG"
case "$*" in
"shell -- cat "*)
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
grep -q 'shell -- pm install -r -S 12' "$TEST_DIR/waydroid.log"
grep -q 'shell -- pm grant dev.lolren.waydroidcameraprobe android.permission.CAMERA' \
	"$TEST_DIR/waydroid.log"
grep -q 'shell -- am force-stop dev.lolren.waydroidcameraprobe' \
	"$TEST_DIR/waydroid.log"

skip_log=$TEST_DIR/waydroid-skip.log
skip_result=$TEST_DIR/result-skip.txt
: >"$skip_log"
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$skip_log" \
	PMOS_WAYDROID_PROBE_SKIP_INSTALL=yes \
	PMOS_WAYDROID_PROBE_TIMEOUT=0 \
	"$RUNNER" "$apk" preview "$skip_result" >"$TEST_DIR/skip-stdout"
grep -q 'shell -- pm path dev.lolren.waydroidcameraprobe' "$skip_log"
if grep -q 'shell -- pm install' "$skip_log"; then
	printf '%s\n' 'skip-install probe unexpectedly invoked package install' >&2
	exit 1
fi
grep -q 'PROBE_DONE profile=preview valid=1 total=1' "$skip_result"

result_720p=$TEST_DIR/result-720p.txt
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$TEST_DIR/waydroid.log" \
	PMOS_WAYDROID_PROBE_CAMERA_ID=0 \
	"$RUNNER" "$apk" record-yuv-720p "$result_720p" >"$TEST_DIR/stdout-720p"
grep -q '^result: ' "$TEST_DIR/stdout-720p"
grep -q 'shell -- am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile record-yuv-720p --es camera-id 0' \
	"$TEST_DIR/waydroid.log"
grep -q 'shell -- rm -f /data/user/0/dev.lolren.waydroidcameraprobe/files/result.txt' \
	"$TEST_DIR/waydroid.log"
grep -q 'shell -- am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile preview' \
	"$TEST_DIR/waydroid.log"

surface_result=$TEST_DIR/surface-result.txt
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$TEST_DIR/waydroid.log" \
	PMOS_WAYDROID_PROBE_TIMEOUT=0 \
	"$RUNNER" "$apk" surface "$surface_result" >"$TEST_DIR/surface-stdout"
grep -q '^result: ' "$TEST_DIR/surface-stdout"
grep -q 'shell -- am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile surface' \
	"$TEST_DIR/waydroid.log"

surface_yuv_result=$TEST_DIR/surface-yuv-result.txt
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$TEST_DIR/waydroid.log" \
	PMOS_WAYDROID_PROBE_TIMEOUT=0 \
	"$RUNNER" "$apk" surface-yuv "$surface_yuv_result" \
	>"$TEST_DIR/surface-yuv-stdout"
grep -q '^result: ' "$TEST_DIR/surface-yuv-stdout"
grep -q 'shell -- am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile surface-yuv' \
	"$TEST_DIR/waydroid.log"

record_result=$TEST_DIR/record-result.txt
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$TEST_DIR/waydroid.log" \
	PMOS_WAYDROID_PROBE_TIMEOUT=0 \
	"$RUNNER" "$apk" record "$record_result" >"$TEST_DIR/record-stdout"
grep -q '^result: ' "$TEST_DIR/record-stdout"
grep -q 'shell -- am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile record' \
	"$TEST_DIR/waydroid.log"

camera_result=$TEST_DIR/camera-result.txt
PATH="$TEST_DIR/bin:$PATH" \
	WAYDROID_TEST_LOG="$TEST_DIR/waydroid.log" \
	PMOS_WAYDROID_PROBE_TIMEOUT=0 \
	PMOS_WAYDROID_PROBE_CAMERA_ID=1 \
	"$RUNNER" "$apk" preview "$camera_result" >"$TEST_DIR/camera-stdout"
grep -q 'shell -- am start -W -n dev.lolren.waydroidcameraprobe/.CameraProbeActivity --es profile preview --es camera-id 1' \
	"$TEST_DIR/waydroid.log"

if PATH="$TEST_DIR/bin:$PATH" "$RUNNER" "$apk" unsupported \
	>"$TEST_DIR/invalid.out" 2>"$TEST_DIR/invalid.err"; then
	printf '%s\n' 'probe runner accepted an unsupported profile' >&2
	exit 1
fi
grep -q 'unsupported profile: unsupported' "$TEST_DIR/invalid.err"

printf '%s\n' 'Waydroid probe runner tests passed'
