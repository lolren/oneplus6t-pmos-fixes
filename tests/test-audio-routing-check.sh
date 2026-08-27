#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK=$ROOT/scripts/check-audio-routing
PACTL=$ROOT/tests/fixtures/audio-pactl
SYSTEMCTL=$ROOT/tests/fixtures/audio-systemctl
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/audio-routing-check-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/proc"

run_check() {
	PMOS_AUDIO_CHECK_PACTL=$PACTL \
	PMOS_AUDIO_CHECK_SYSTEMCTL=$SYSTEMCTL \
	PMOS_AUDIO_CHECK_PROC_ROOT=$TEST_DIR/proc \
	PMOS_AUDIO_SINK=alsa_output.platform-sound.HiFi__Speaker__sink \
	PMOS_AUDIO_CURRENT_SOURCE=alsa_input.platform-sound.HiFi__Mic2__source \
	PMOS_AUDIO_SERVER_NAME="${PMOS_TEST_SERVER_NAME:-PulseAudio (on PipeWire mock)}" \
		sh "$CHECK"
}

run_check >"$TEST_DIR/pass.out"
grep -q '^PulseAudio (on PipeWire mock)$' "$TEST_DIR/pass.out"
grep -q '^pipewire-pulse.socket' "$TEST_DIR/pass.out"
grep -q 'alsa_input.platform-sound.HiFi__Mic2__source' "$TEST_DIR/pass.out"

if PMOS_TEST_SERVER_NAME='pulseaudio 17.0' run_check \
	>"$TEST_DIR/legacy.out" 2>"$TEST_DIR/legacy.err"; then
	echo 'legacy PulseAudio server unexpectedly passed' >&2
	exit 1
fi
grep -q '^Wrong PulseAudio server: pulseaudio 17.0$' "$TEST_DIR/legacy.err"

mkdir -p "$TEST_DIR/proc/123"
printf '%s\n' pulseaudio >"$TEST_DIR/proc/123/comm"
if run_check >"$TEST_DIR/process.out" 2>"$TEST_DIR/process.err"; then
	echo 'conflicting pulseaudio process unexpectedly passed' >&2
	exit 1
fi
grep -q '^Conflicting pulseaudio process detected (PID 123)$' \
	"$TEST_DIR/process.err"

printf '%s\n' 'audio routing diagnostic tests passed'
