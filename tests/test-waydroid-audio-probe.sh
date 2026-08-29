#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROBE_SOURCE=$ROOT/tests/waydroid-audio-probe/src/dev/lolren/waydroidaudioprobe/AudioProbeActivity.java
PROBE_BUILD=$ROOT/tests/waydroid-audio-probe/build.sh
PIPEWIRE_CONFIG=$ROOT/config/pipewire/90-oneplus6t-waydroid.conf
WAYDROID_INIT=$ROOT/config/waydroid/init.zz-oneplus6t-camera.rc.in
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-audio-probe-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

sh -n "$PROBE_BUILD"
grep -q 'STREAM_MUSIC' "$PROBE_SOURCE"
grep -q 'USAGE_MEDIA' "$PROBE_SOURCE"
grep -q 'AudioTrack.MODE_STREAM' "$PROBE_SOURCE"
grep -q 'track.setVolume(1.0f)' "$PROBE_SOURCE"
grep -q 'AudioTrack.WRITE_BLOCKING' "$PROBE_SOURCE"
grep -q 'DURATION_SECONDS = 20' "$PROBE_SOURCE"
grep -q 'default.clock.min-quantum = 512' "$PIPEWIRE_CONFIG"
grep -q 'waydroid.pulse_runtime_path /run/xdg/pulse' "$WAYDROID_INIT"

stage=$TEST_DIR/stage
make -s -C "$ROOT" install DESTDIR="$stage" PREFIX=/usr >/dev/null
test -f "$stage/etc/pipewire/pipewire.conf.d/90-oneplus6t-waydroid.conf"
cmp "$PIPEWIRE_CONFIG" \
	"$stage/etc/pipewire/pipewire.conf.d/90-oneplus6t-waydroid.conf"
test -f "$stage/usr/libexec/oneplus6t-pmos-fixes/config/waydroid/init.zz-oneplus6t-camera.rc.in"

printf '%s\n' 'Waydroid audio bridge configuration and probe tests passed'
