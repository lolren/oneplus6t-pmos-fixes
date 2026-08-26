#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SERVICE=$ROOT/config/systemd/oneplus6t-waydroid-location.service

[ -f "$SERVICE" ]
grep -q '^After=ModemManager\.service waydroid-container\.service$' "$SERVICE"
grep -q '^Wants=ModemManager\.service waydroid-container\.service$' "$SERVICE"
grep -q '^ConditionPathExists=@SBINDIR@/pmos-waydroid-location-bridge$' "$SERVICE"
grep -q '^ExecStart=@SBINDIR@/pmos-waydroid-location-bridge --source mmcli --enable-gps --provider fused --apply$' "$SERVICE"
grep -q '^Restart=on-failure$' "$SERVICE"
grep -q '^KillSignal=SIGINT$' "$SERVICE"

# Installing the unit alone must not start GNSS or create an Android mock
# provider; enabling it is an explicit administrator action.
! grep -q '^WantedBy=' "$SERVICE"
! grep -q 'systemctl.*enable.*oneplus6t-waydroid-location' "$ROOT/Makefile"

stage=$(mktemp -d "${TMPDIR:-/tmp}/location-service-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
make -s -C "$ROOT" install DESTDIR="$stage" PREFIX=/usr >/dev/null
grep -q '^ConditionPathExists=/usr/sbin/pmos-waydroid-location-bridge$' \
	"$stage/usr/lib/systemd/system/oneplus6t-waydroid-location.service"
grep -q '^ExecStart=/usr/sbin/pmos-waydroid-location-bridge --source mmcli --enable-gps --provider fused --apply$' \
	"$stage/usr/lib/systemd/system/oneplus6t-waydroid-location.service"

printf '%s\n' 'location service tests passed'
