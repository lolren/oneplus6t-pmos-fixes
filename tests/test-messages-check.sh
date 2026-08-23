#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
CHECK=$ROOT/scripts/check-messages
MOCK_BIN=$TEST_DIR/fixtures/messages-bin
DESKTOP=$TEST_DIR/fixtures/sm.puri.Chatty.desktop
STATE_ROOT=$(mktemp -d)
trap 'rm -r -- "$STATE_ROOT"' EXIT HUP INT TERM
STATE=$STATE_ROOT/window-present

run_check() {
	PATH="$MOCK_BIN:/usr/bin:/bin" \
	PMOS_CHATTY_DESKTOP="$DESKTOP" \
	PMOS_MOCK_WINDOW_STATE="$STATE" \
	PMOS_CHATTY_TIMEOUT_TENTHS=2 \
	DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/mock-bus \
	"$CHECK" "$@"
}

initial=$(run_check)
printf '%s\n' "$initial" | grep -q '^desktop_file=ok$'
printf '%s\n' "$initial" | grep -q '^libraries=resolved$'
printf '%s\n' "$initial" | grep -q '^daemon_service=active$'
printf '%s\n' "$initial" | grep -q '^dbus_owner=present$'
printf '%s\n' "$initial" | grep -q '^window=absent$'

tree_probe=$STATE_ROOT/tree-probed
ownerless=$(PATH="$MOCK_BIN:/usr/bin:/bin" \
	PMOS_CHATTY_DESKTOP="$DESKTOP" PMOS_MOCK_WINDOW_STATE="$STATE" \
	PMOS_MOCK_DBUS_OWNER=no PMOS_MOCK_TREE_PROBE="$tree_probe" \
	DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/mock-bus "$CHECK")
printf '%s\n' "$ownerless" | grep -q '^dbus_owner=absent$'
printf '%s\n' "$ownerless" | grep -q '^window=absent$'
if [ -e "$tree_probe" ]; then
	printf 'read-only check unexpectedly activated or introspected absent owner\n' >&2
	exit 1
fi

activated=$(run_check --activate)
printf '%s\n' "$activated" | grep -q '^activation=ok$'
printf '%s\n' "$activated" | grep -q '^window_after_activation=present$'
printf '%s\n' "$activated" | grep -q '^window_poll_tenths=0$'

if PMOS_CHATTY_DESKTOP="$STATE_ROOT/not-present.desktop" \
	PATH="$MOCK_BIN:/usr/bin:/bin" PMOS_MOCK_WINDOW_STATE="$STATE" \
	DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/mock-bus "$CHECK" >/dev/null 2>&1; then
	printf 'missing desktop file unexpectedly passed\n' >&2
	exit 1
fi

printf 'Messages diagnostic tests passed\n'
