#!/bin/sh
set -eu

# Keep the sensor expectations aligned with the r24 reference stack and the
# generation selected by --focus-result.

usage() {
	cat <<'EOF'
Usage: validate-pipewire-af.sh --output DIR [options]

Options:
  --focus-helper FILE      installed helper path
                           (default: /usr/libexec/advanced-snapshot-focus-control)
  --focus-result MODE      required for r7/r1, accepted for r6/r0
                           (default: required)
  --stability-seconds N    post-reset rear-camera window (default: 60)
  --close-camera-apps      terminate Snapshot/Advanced Snapshot before testing
  --help                   show this help

Run this as the graphical login user on the OnePlus 6T. The test restarts only
the user's PipeWire and WirePlumber services, discovers ephemeral camera
serials, validates both rear tap/reset transitions, holds each rear stream for
the requested stability window, and checks the fixed-focus front camera.

The output directory must be empty. Existing LIBCAMERA_LOG_* service variables
are restored on every exit. No root access, reboot, module operation or camera
image is used.
EOF
}

output=
focus_helper=/usr/libexec/advanced-snapshot-focus-control
focus_result_mode=required
stability_seconds=60
close_camera_apps=false

while [ "$#" -gt 0 ]; do
	case "$1" in
	--output)
		output=${2:?missing output directory}
		shift 2
		;;
	--focus-helper)
		focus_helper=${2:?missing helper path}
		shift 2
		;;
	--focus-result)
		focus_result_mode=${2:?missing focus-result mode}
		shift 2
		;;
	--stability-seconds)
		stability_seconds=${2:?missing stability duration}
		shift 2
		;;
	--close-camera-apps)
		close_camera_apps=true
		shift
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

case "$focus_result_mode" in
required|accepted) ;;
*)
	printf '%s\n' '--focus-result must be required or accepted' >&2
	exit 2
	;;
esac

[ -n "$output" ] || { printf '%s\n' 'Missing --output' >&2; exit 2; }
case "$stability_seconds" in
''|*[!0-9]*)
	printf '%s\n' '--stability-seconds must be an integer' >&2
	exit 2
	;;
esac
[ "$stability_seconds" -ge 10 ] && [ "$stability_seconds" -le 300 ] || {
	printf '%s\n' '--stability-seconds must be between 10 and 300' >&2
	exit 2
}

for command_name in systemctl timeout gst-launch-1.0 gst-device-monitor-1.0 \
	awk sed grep find mktemp pgrep pkill; do
	command -v "$command_name" >/dev/null 2>&1 || {
		printf 'Missing required command: %s\n' "$command_name" >&2
		exit 1
	}
done
[ -x "$focus_helper" ] || {
	printf 'Missing executable focus helper: %s\n' "$focus_helper" >&2
	exit 1
}

if [ -d "$output" ] && [ -n "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
	printf 'Refusing non-empty output directory: %s\n' "$output" >&2
	exit 1
fi
mkdir -p "$output"
output=$(CDPATH= cd -- "$output" && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/oneplus6t-af.XXXXXX")

pipewire_active=$(systemctl --user is-active pipewire.service 2>/dev/null || true)
wireplumber_active=$(systemctl --user is-active wireplumber.service 2>/dev/null || true)
portal_active=$(systemctl --user is-active xdg-desktop-portal.service 2>/dev/null || true)
wlr_portal_active=$(systemctl --user is-active xdg-desktop-portal-wlr.service 2>/dev/null || true)
[ "$pipewire_active" = active ] && [ "$wireplumber_active" = active ] || {
	printf '%s\n' 'PipeWire and WirePlumber must both be active before the test' >&2
	rmdir "$scratch"
	exit 1
}

service_environment=$(systemctl --user show-environment)
old_log_file=$(printf '%s\n' "$service_environment" | sed -n 's/^LIBCAMERA_LOG_FILE=//p')
old_log_levels=$(printf '%s\n' "$service_environment" | sed -n 's/^LIBCAMERA_LOG_LEVELS=//p')
had_log_file=false
had_log_levels=false
[ -n "$old_log_file" ] && had_log_file=true
[ -n "$old_log_levels" ] && had_log_levels=true

stream_pid=
cleanup_started=false

stop_stream() {
	if [ -n "$stream_pid" ] && kill -0 "$stream_pid" 2>/dev/null; then
		kill -TERM "$stream_pid" 2>/dev/null || true
		wait "$stream_pid" 2>/dev/null || true
	fi
	stream_pid=
}

restore_services() {
	$cleanup_started && return
	cleanup_started=true
	trap - EXIT HUP INT TERM
	stop_stream
	if [ "$portal_active" = active ] || [ "$wlr_portal_active" = active ]; then
		systemctl --user stop xdg-desktop-portal.service \
			xdg-desktop-portal-wlr.service >/dev/null 2>&1 || true
	fi
	systemctl --user unset-environment LIBCAMERA_LOG_FILE LIBCAMERA_LOG_LEVELS \
		>/dev/null 2>&1 || true
	$had_log_file && systemctl --user set-environment \
		"LIBCAMERA_LOG_FILE=$old_log_file"
	$had_log_levels && systemctl --user set-environment \
		"LIBCAMERA_LOG_LEVELS=$old_log_levels"
	# pMOS uses socket activation. Stopping the socket and service in one
	# transaction can return "job canceled" while leaving PipeWire alive with
	# stale camera links. Restart the services individually instead.
	systemctl --user restart pipewire.service >/dev/null 2>&1 || true
	systemctl --user restart wireplumber.service >/dev/null 2>&1 || true
	if [ "$portal_active" = active ] || [ "$wlr_portal_active" = active ]; then
		systemctl --user reset-failed xdg-desktop-portal.service \
			xdg-desktop-portal-wlr.service >/dev/null 2>&1 || true
		[ "$wlr_portal_active" != active ] || systemctl --user start \
			xdg-desktop-portal-wlr.service >/dev/null 2>&1 || true
		[ "$portal_active" != active ] || systemctl --user start \
			xdg-desktop-portal.service >/dev/null 2>&1 || true
	fi
	rm -f "$scratch/devices"
	rmdir "$scratch" 2>/dev/null || true
}
trap restore_services EXIT
trap 'restore_services; exit 130' HUP INT TERM

camera_app_active() {
	pgrep -x snapshot >/dev/null 2>&1 || \
		pgrep -f '(^|/)advanced-snapshot( |$)' >/dev/null 2>&1
}

if camera_app_active; then
	if $close_camera_apps; then
		pkill -TERM -x snapshot 2>/dev/null || true
		pkill -TERM -f '(^|/)advanced-snapshot( |$)' 2>/dev/null || true
		for _wait in 1 2 3 4 5; do
			camera_app_active || break
			sleep 1
		done
		if camera_app_active; then
			printf '%s\n' 'A camera app did not stop within five seconds' >&2
			exit 1
		fi
	else
		printf '%s\n' \
			'A camera app is active; close it or pass --close-camera-apps' >&2
		exit 1
	fi
fi
if pgrep -x gst-launch-1.0 >/dev/null 2>&1; then
	printf '%s\n' 'Another gst-launch-1.0 process is active' >&2
	exit 1
fi

restart_camera_services() {
	log_file=$1
	if [ "$portal_active" = active ] || [ "$wlr_portal_active" = active ]; then
		systemctl --user stop xdg-desktop-portal.service \
			xdg-desktop-portal-wlr.service >/dev/null 2>&1 || true
	fi
	: >"$log_file"
	systemctl --user set-environment \
		"LIBCAMERA_LOG_FILE=$log_file" \
		'LIBCAMERA_LOG_LEVELS=*:ERROR,IPASoftAf:DEBUG'
	# Restart the service, keeping its socket. This avoids systemd canceling the
	# combined stop transaction on socket-activated pMOS user units.
	systemctl --user restart pipewire.service
	systemctl --user restart wireplumber.service
	if [ "$portal_active" = active ] || [ "$wlr_portal_active" = active ]; then
		systemctl --user reset-failed xdg-desktop-portal.service \
			xdg-desktop-portal-wlr.service >/dev/null 2>&1 || true
		[ "$wlr_portal_active" != active ] || \
			systemctl --user start xdg-desktop-portal-wlr.service
		[ "$portal_active" != active ] || \
			systemctl --user start xdg-desktop-portal.service
	fi
	sleep 3
}

discover_serial() {
	sensor=$1
	monitor_status=0
	timeout 8 gst-device-monitor-1.0 Video/Source >"$scratch/devices" 2>&1 || \
		monitor_status=$?
	[ "$monitor_status" -eq 0 ] || [ "$monitor_status" -eq 124 ] || {
		printf 'Camera discovery failed with status %s\n' "$monitor_status" >&2
		return 1
	}
	awk -v wanted="$sensor" '
		/object.path = libcamera:/ { path = $3 }
		/device.product.name = / { product = $3 }
		/object.serial = / {
			if (path != "" && product == wanted) {
				print $3
				exit
			}
		}
	' "$scratch/devices"
}

settle_count() {
	awk '/Autofocus settled/{ count++ } END { print count + 0 }' "$1"
}

wait_for_new_settle() {
	log_file=$1
	previous=$2
	seconds=0
	while [ "$seconds" -lt 25 ]; do
		current=$(settle_count "$log_file")
		[ "$current" -gt "$previous" ] && return 0
		if [ -n "$stream_pid" ] && ! kill -0 "$stream_pid" 2>/dev/null; then
			printf '%s\n' 'Camera stream exited before autofocus settled' >&2
			return 1
		fi
		seconds=$((seconds + 1))
		sleep 1
	done
	printf '%s\n' 'Timed out waiting for autofocus to settle' >&2
	return 1
}

start_stream() {
	serial=$1
	stream_log=$2
	gst-launch-1.0 -q pipewiresrc target-object="$serial" \
		! 'video/x-raw,format=RGBA,width=640,height=480' \
		! fakesink sync=false >"$stream_log" 2>&1 &
	stream_pid=$!
}

validate_rear() {
	sensor=$1
	name=$2
	log_file="$output/$name-af.log"
	stream_log="$output/$name-stream.log"
	reset_section="$output/$name-after-reset.log"

	restart_camera_services "$log_file"
	serial=$(discover_serial "$sensor")
	[ -n "$serial" ] || {
		printf 'Could not discover PipeWire serial for %s\n' "$sensor" >&2
		return 1
	}
	start_stream "$serial" "$stream_log"
	wait_for_new_settle "$log_file" 0

	before=$(settle_count "$log_file")
	focus_result_file="$output/$name-focus-result.txt"
	focus_error_file="$output/$name-focus-helper.log"
	helper_status=0
	# Use the centre of the deliberately staged target. An arbitrary low-detail
	# off-centre window may truthfully return Failed and is not a transport bug.
	timeout 20 "$focus_helper" focus "$serial" 0.50 0.50 0.18 \
		>"$focus_result_file" 2>"$focus_error_file" || helper_status=$?
	[ "$helper_status" -eq 0 ] || {
		printf '%s: focus helper returned %s\n' "$name" "$helper_status" >&2
		return 1
	}
	if [ "$focus_result_mode" = required ]; then
		grep -qx 'focused' "$focus_result_file" || {
			printf '%s: autofocus did not report metadata-confirmed focus\n' \
				"$name" >&2
			return 1
		}
		tap_result=focused
	else
		tap_result=accepted
	fi
	wait_for_new_settle "$log_file" "$before"

	reset_start=$(wc -l <"$log_file")
	timeout 20 "$focus_helper" reset "$serial"
	sleep 5
	sed -n "$((reset_start + 1)),\$p" "$log_file" >"$reset_section"
	grep -q 'Resuming continuous autofocus at lens position .* without a scan' \
		"$reset_section" || {
		printf '%s: scan-free continuous transition was not logged\n' "$name" >&2
		return 1
	}
	grep -q 'Continuous focus reference initialized' "$reset_section" || {
		printf '%s: continuous reference was not initialized\n' "$name" >&2
		return 1
	}
	if grep -q 'Requesting lens position' "$reset_section"; then
		printf '%s: lens moved during reset\n' "$name" >&2
		return 1
	fi

	sleep "$stability_seconds"
	if ! kill -0 "$stream_pid" 2>/dev/null; then
		printf '%s: stream exited during stability window\n' "$name" >&2
		return 1
	fi
	sed -n "$((reset_start + 1)),\$p" "$log_file" >"$reset_section"
	if grep -q 'Restarting autofocus\|Requesting lens position' "$reset_section"; then
		printf '%s: autofocus restarted or moved after reset\n' "$name" >&2
		return 1
	fi
	metrics=$(grep -c 'Continuous focus metric' "$reset_section" || true)
	[ "$metrics" -gt 0 ] || {
		printf '%s: no continuous-focus measurements were recorded\n' "$name" >&2
		return 1
	}
	stop_stream
	printf '%s|serial=%s|tap_result=%s|post_reset_metrics=%s|restarts=0|lens_requests=0\n' \
		"$name" "$serial" "$tap_result" "$metrics" >>"$output/summary.psv"
}

validate_front() {
	log_file="$output/front-af.log"
	stream_log="$output/front-stream.log"
	restart_camera_services "$log_file"
	serial=$(discover_serial imx371)
	[ -n "$serial" ] || {
		printf '%s\n' 'Could not discover PipeWire serial for imx371' >&2
		return 1
	}
	timeout 30 gst-launch-1.0 -q pipewiresrc target-object="$serial" \
		num-buffers=120 \
		! 'video/x-raw,format=RGBA,width=640,height=480' \
		! fakesink sync=false >"$stream_log" 2>&1

	helper_status=0
	timeout 10 "$focus_helper" focus "$serial" 0.50 0.50 0.18 \
		>"$output/front-focus-helper.log" 2>&1 || helper_status=$?
	[ "$helper_status" -eq 3 ] || {
		printf 'Front focus helper returned %s, expected 3\n' "$helper_status" >&2
		return 1
	}
	grep -q 'camera does not support tap-to-focus' \
		"$output/front-focus-helper.log"
	[ ! -s "$log_file" ] || {
		printf '%s\n' 'Fixed-focus front unexpectedly produced autofocus logs' >&2
		return 1
	}
	printf 'front|serial=%s|frames=120|focus_status=unsupported\n' "$serial" \
		>>"$output/summary.psv"
}

: >"$output/summary.psv"
validate_rear imx519 main
validate_rear imx376 secondary
validate_front

printf 'RESULT|pass|rear_stability_seconds=%s\n' "$stability_seconds" \
	>>"$output/summary.psv"
printf 'PASS: %s\n' "$output"
