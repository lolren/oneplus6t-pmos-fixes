#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPORT=$ROOT/scripts/check-location
TEST_DIR=$(mktemp -d /tmp/location-report-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

output=$TEST_DIR/report.txt
PMOS_LOCATION_MMCLI="$ROOT/tests/fixtures/location-mmcli" \
	PMOS_LOCATION_SYSTEMCTL="$ROOT/tests/fixtures/location-systemctl" \
	PMOS_LOCATION_NMCLI=/missing/nmcli \
	"$REPORT" --output "$output"
grep -Fqx 'modem=0' "$output"
grep -Fqx 'location_status_status=0' "$output"
grep -Fqx 'location_get_status=0' "$output"
grep -Fqx 'geoclue=active' "$output"
grep -Fqx 'latitude_fields=yes' "$output"
grep -Fqx 'longitude_fields=yes' "$output"
grep -Fqx 'native_fix=coordinates-present' "$output"
grep -q '^note=this report never enables GPS,' "$output"

printf '%s\n' 'location report tests passed'
