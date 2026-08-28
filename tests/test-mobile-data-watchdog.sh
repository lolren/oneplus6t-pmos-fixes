#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WATCHDOG=$ROOT/scripts/mobile-data-watchdog
NMCLI=$ROOT/tests/fixtures/mobile-watchdog-nmcli
MMCLI=$ROOT/tests/fixtures/mobile-watchdog-mmcli
IP=$ROOT/tests/fixtures/mobile-watchdog-ip
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mobile-watchdog-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

STATE_DIR=$TEST_DIR/state
RUNTIME_DIR=$TEST_DIR/run
LOG=$TEST_DIR/nmcli.log
UUID=11111111-2222-3333-4444-555555555555
mkdir -p "$STATE_DIR" "$RUNTIME_DIR"
printf '%s\n' "$UUID" >"$STATE_DIR/mobile-data-profile.uuid"
: >"$LOG"

run_watchdog() {
	PMOS_MOBILE_STATE_DIR=$STATE_DIR \
	PMOS_MOBILE_WATCHDOG_RUNTIME_DIR=$RUNTIME_DIR \
	PMOS_MOBILE_WATCHDOG_NMCLI=$NMCLI \
	PMOS_MOBILE_WATCHDOG_MMCLI=$MMCLI \
	PMOS_MOBILE_WATCHDOG_IP=$IP \
	PMOS_MOBILE_WATCHDOG_UID=0 \
	PMOS_MOBILE_WATCHDOG_NOW="${PMOS_TEST_NOW:-1000}" \
	PMOS_WATCHDOG_HEALTH="${PMOS_TEST_HEALTH:-healthy}" \
	PMOS_WATCHDOG_NM_STATE="${PMOS_TEST_NM_STATE:-activated}" \
	PMOS_WATCHDOG_PROFILE_TYPE="${PMOS_TEST_PROFILE_TYPE:-gsm}" \
	PMOS_WATCHDOG_VOICE_CALLS="${PMOS_TEST_VOICE_CALLS:-0}" \
	PMOS_WATCHDOG_LOG=$LOG \
		sh "$WATCHDOG" "$@"
}

run_watchdog --check >"$TEST_DIR/healthy.out"
grep -q '^status=healthy$' "$TEST_DIR/healthy.out"
grep -q '^action=none$' "$TEST_DIR/healthy.out"
[ ! -s "$LOG" ]

if PMOS_TEST_HEALTH=stale run_watchdog --check \
	>"$TEST_DIR/stale.out" 2>"$TEST_DIR/stale.err"; then
	echo 'stale activated connection unexpectedly passed a read-only check' >&2
	exit 1
fi
grep -q '^status=stale-activated$' "$TEST_DIR/stale.out"
grep -q '^action=repair-required$' "$TEST_DIR/stale.out"
[ ! -s "$LOG" ]

PMOS_TEST_HEALTH=repairable run_watchdog --repair >"$TEST_DIR/repair.out"
grep -q '^action=reconnected$' "$TEST_DIR/repair.out"
grep -q '^result=pass$' "$TEST_DIR/repair.out"
[ "$(sed -n '1p' "$LOG")" = down ]
[ "$(sed -n '2p' "$LOG")" = up ]

before=$(wc -l <"$LOG")
PMOS_TEST_HEALTH=stale PMOS_TEST_NOW=1100 run_watchdog --repair \
	>"$TEST_DIR/cooldown.out"
grep -q '^action=deferred-cooldown$' "$TEST_DIR/cooldown.out"
[ "$(wc -l <"$LOG")" -eq "$before" ]

PMOS_TEST_NM_STATE=deactivated run_watchdog --repair >"$TEST_DIR/inactive.out"
grep -q '^status=inactive$' "$TEST_DIR/inactive.out"
grep -q '^action=networkmanager-autoconnect$' "$TEST_DIR/inactive.out"

before=$(wc -l <"$LOG")
PMOS_TEST_HEALTH=stale PMOS_TEST_VOICE_CALLS=1 PMOS_TEST_NOW=2000 \
	run_watchdog --repair >"$TEST_DIR/call.out"
grep -q '^action=deferred-active-call$' "$TEST_DIR/call.out"
[ "$(wc -l <"$LOG")" -eq "$before" ]

if PMOS_TEST_PROFILE_TYPE=wifi run_watchdog --check \
	>"$TEST_DIR/type.out" 2>"$TEST_DIR/type.err"; then
	echo 'non-GSM marker unexpectedly passed' >&2
	exit 1
fi
grep -q 'points to a non-GSM connection' "$TEST_DIR/type.err"

rm "$STATE_DIR/mobile-data-profile.uuid"
run_watchdog --check >"$TEST_DIR/unmanaged.out"
grep -q '^status=unmanaged$' "$TEST_DIR/unmanaged.out"

stage=$TEST_DIR/stage
make -s -C "$ROOT" install DESTDIR="$stage" PREFIX=/usr >/dev/null
grep -q 'mobile-data-watchdog --repair' \
	"$stage/usr/lib/systemd/system/oneplus6t-mobile-data-watchdog.service"
[ "$(stat -c %a "$stage/usr/lib/systemd/system/oneplus6t-mobile-data-watchdog.service")" = 644 ]
grep -q '^OnUnitActiveSec=5min$' \
	"$stage/usr/lib/systemd/system/oneplus6t-mobile-data-watchdog.timer"
[ -x "$stage/usr/libexec/oneplus6t-pmos-fixes/scripts/mobile-data-watchdog" ]
[ -L "$stage/usr/sbin/pmos-mobile-data-watchdog" ]
grep -q 'enable --now "$WATCHDOG_TIMER"' "$ROOT/scripts/configure-mobile-data"
grep -q 'disable --now "$WATCHDOG_TIMER"' "$ROOT/scripts/remove-mobile-data"

printf '%s\n' 'mobile-data watchdog tests passed'
