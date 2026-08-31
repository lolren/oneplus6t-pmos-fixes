#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SERVICE=$ROOT/config/systemd/oneplus6t-waydroid-session.service
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/waydroid-session-service-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

[ -f "$SERVICE" ] || {
	printf '%s\n' 'missing persistent Waydroid session service' >&2
	exit 1
}

grep -Fqx 'Requires=waydroid-container.service' "$SERVICE"
grep -Fqx 'PartOf=waydroid-container.service' "$SERVICE"
grep -Fqx 'User=user' "$SERVICE"
grep -Fqx 'Group=user' "$SERVICE"
grep -Fqx 'Environment=HOME=%h' "$SERVICE"
grep -Fqx 'Environment=XDG_RUNTIME_DIR=/run/user/%U' "$SERVICE"
grep -Fqx 'Environment=WAYLAND_DISPLAY=wayland-0' "$SERVICE"
grep -Fqx 'Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus' "$SERVICE"
grep -Fqx 'ExecStart=/usr/bin/waydroid session start' "$SERVICE"
grep -Fqx 'ExecStop=/usr/bin/waydroid session stop' "$SERVICE"
grep -Fqx 'WantedBy=graphical.target' "$SERVICE"
grep -Fq 'XDG_RUNTIME_DIR/wayland-0' "$SERVICE"
! grep -Fq 'systemd-run --user' "$SERVICE"
! grep -Fq 'ssh' "$SERVICE"

make -C "$ROOT" DESTDIR="$TEST_DIR" PREFIX=/usr install >/dev/null
installed=$TEST_DIR/usr/lib/systemd/system/oneplus6t-waydroid-session.service
[ -f "$installed" ]
[ "$(stat -c %a "$installed")" = 644 ]
cmp "$SERVICE" "$installed"

printf '%s\n' 'Waydroid graphical-session service tests passed'
