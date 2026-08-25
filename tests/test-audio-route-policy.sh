#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
POLICY=$ROOT/scripts/audio-route-policy
PACTL=$ROOT/tests/fixtures/audio-pactl
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/audio-route-policy-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

run_case() {
	sink=$1
	expected=$2
	log=$TEST_DIR/$(printf '%s' "$expected" | tr '/_' '__').log
	PMOS_PACTL=$PACTL \
	PMOS_AUDIO_SINK="$sink" \
	PMOS_AUDIO_CURRENT_SOURCE=alsa_input.platform-sound.unrelated_source \
	PMOS_AUDIO_LOG="$log" \
		sh "$POLICY" --once
	grep -qx "$expected" "$log"
}

run_case \
	alsa_output.platform-sound.HiFi__Speaker__sink \
	alsa_input.platform-sound.HiFi__Mic2__source
run_case \
	alsa_output.platform-sound.Voice_Call__Earpiece__sink \
	alsa_input.platform-sound.Voice_Call__Mic__source
run_case \
	alsa_output.platform-sound.HiFi__Headphones__sink \
	alsa_input.platform-sound.Headset__source

printf '%s\n' 'audio route policy tests passed'
