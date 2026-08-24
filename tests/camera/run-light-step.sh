#!/bin/sh
set -eu

usage() {
	cat <<'EOF'
Usage: run-light-step.sh --runtime DIR --camera ID --output DIR [options]

Options:
  --focus-helper FILE  v4l2-focus-control.py path
  --frames COUNT       bounded capture length (default: 360)
  --help               show this help

Only the OnePlus 6T rear camera IDs are accepted. The test briefly drives the
white/yellow flash LEDs at 32/16 out of 255, records metadata, turns both LEDs
off and parks the matched actuator at DAC 0, including on interruption.
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runtime=
camera=
output=
focus_helper="$script_dir/../../scripts/v4l2-focus-control.py"
frames=360

while [ "$#" -gt 0 ]; do
	case "$1" in
	--runtime)
		runtime=${2:?missing runtime directory}
		shift 2
		;;
	--camera)
		camera=${2:?missing camera ID}
		shift 2
		;;
	--output)
		output=${2:?missing output directory}
		shift 2
		;;
	--focus-helper)
		focus_helper=${2:?missing focus helper path}
		shift 2
		;;
	--frames)
		frames=${2:?missing frame count}
		shift 2
		;;
	--help|-h)
		usage
		exit 0
		;;
	*)
		printf 'Unknown argument: %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
done

[ -n "$runtime" ] || { printf '%s\n' 'Missing --runtime' >&2; exit 2; }
[ -n "$camera" ] || { printf '%s\n' 'Missing --camera' >&2; exit 2; }
[ -n "$output" ] || { printf '%s\n' 'Missing --output' >&2; exit 2; }
case "$frames" in
''|*[!0-9]*) printf '%s\n' 'Frame count must be an integer' >&2; exit 2 ;;
esac
[ "$frames" -ge 240 ] || {
	printf '%s\n' 'Use at least 240 frames for both light transitions' >&2
	exit 2
}

case "$camera" in
/base/soc@0/cci@ac4a000/i2c-bus@0/camera@1a)
	actuator_prefix='lc898217xc 16-'
	name=main
	;;
/base/soc@0/cci@ac4a000/i2c-bus@1/camera@10)
	actuator_prefix='lc898217xc 17-'
	name=secondary
	;;
*)
	printf 'Refusing unsupported or fixed-focus camera ID: %s\n' "$camera" >&2
	exit 2
	;;
esac

cam="$runtime/usr/bin/cam"
white=/sys/class/leds/white:flash/brightness
yellow=/sys/class/leds/yellow:flash/brightness
[ -x "$cam" ] || { printf 'Missing cam binary: %s\n' "$cam" >&2; exit 1; }
[ -f "$focus_helper" ] || {
	printf 'Missing focus helper: %s\n' "$focus_helper" >&2
	exit 1
}
[ -w "$white" ] && [ -w "$yellow" ] || {
	printf '%s\n' 'Flash LED controls are not writable by this user' >&2
	exit 1
}
if ps -o comm | grep -Eq '^[[:space:]]*(cam|qcam|megapixels)[[:space:]]*$'; then
	printf '%s\n' 'Refusing to run while another camera application is active' >&2
	exit 1
fi

actuator=
for node in /sys/class/video4linux/v4l-subdev*; do
	device_name=$(cat "$node/name" 2>/dev/null || true)
	case "$device_name" in
	"$actuator_prefix"*) actuator="/dev/${node##*/}" ;;
	esac
done
[ -n "$actuator" ] || {
	printf 'No actuator matched %s\n' "$actuator_prefix" >&2
	exit 1
}

mkdir -p "$output"
log="$output/$name-light-step.log"
markers="$output/$name-light-step.markers"
park_log="$output/$name-light-step-park.log"
camera_pid=

cleanup() {
	printf '0\n' >"$white" 2>/dev/null || true
	printf '0\n' >"$yellow" 2>/dev/null || true
	if [ -n "$camera_pid" ] && kill -0 "$camera_pid" 2>/dev/null; then
		kill -TERM "$camera_pid" 2>/dev/null || true
		wait "$camera_pid" 2>/dev/null || true
	fi
	python3 "$focus_helper" "$actuator" --set 0 >"$park_log" 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

printf 'off %s\n' "$(cut -d' ' -f1 /proc/uptime)" >"$markers"
LD_LIBRARY_PATH="$runtime/usr/lib" \
LIBCAMERA_IPA_MODULE_PATH="$runtime/usr/lib/libcamera/ipa" \
LIBCAMERA_IPA_PROXY_PATH="$runtime/usr/libexec/libcamera" \
LIBCAMERA_IPA_CONFIG_PATH="$runtime/usr/share/libcamera/ipa" \
"$cam" --camera "$camera" --capture="$frames" \
	--stream role=still,width=800,height=600,pixelformat=ABGR8888 \
	--metadata >"$log" 2>&1 &
camera_pid=$!

sleep 3
printf '32\n' >"$white"
printf '16\n' >"$yellow"
printf 'on %s\n' "$(cut -d' ' -f1 /proc/uptime)" >>"$markers"
sleep 3
printf '0\n' >"$white"
printf '0\n' >"$yellow"
printf 'off %s\n' "$(cut -d' ' -f1 /proc/uptime)" >>"$markers"

wait "$camera_pid"
camera_pid=
printf 'metadata=%s\nmarkers=%s\npark=%s\n' "$log" "$markers" "$park_log"
