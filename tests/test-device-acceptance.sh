#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNNER=$ROOT/scripts/run-device-acceptance
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/device-acceptance-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

mkdir -p "$TEST_DIR/bin"
printf 'oneplus,fajita\000qcom,sdm845\000' >"$TEST_DIR/compatible"

make_check() {
	name=$1
	path=$TEST_DIR/bin/$name
	{
		printf '%s\n' '#!/bin/sh'
		printf '%s\n' 'printf "%s\\n" "$@"'
		printf '%s\n' 'exit 0'
	} >"$path"
	chmod 0755 "$path"
}

for check in mobile-data audio display location nfc power waydroid; do
	make_check "$check"
done

output=$TEST_DIR/output
PMOS_ACCEPT_COMPATIBLE_FILE="$TEST_DIR/compatible" \
PMOS_ACCEPT_MOBILE_DATA_CHECK="$TEST_DIR/bin/mobile-data" \
PMOS_ACCEPT_AUDIO_CHECK="$TEST_DIR/bin/audio" \
PMOS_ACCEPT_DISPLAY_CHECK="$TEST_DIR/bin/display" \
PMOS_ACCEPT_LOCATION_CHECK="$TEST_DIR/bin/location" \
PMOS_ACCEPT_NFC_CHECK="$TEST_DIR/bin/nfc" \
PMOS_ACCEPT_POWER_CHECK="$TEST_DIR/bin/power" \
PMOS_ACCEPT_WAYDROID_CHECK="$TEST_DIR/bin/waydroid" \
	"$RUNNER" --output "$output" --nfc-poll

grep -Fqx 'compatibility|0|'"$output/compatibility.log" "$output/summary.psv"
grep -Fqx 'nfc|0|'"$output/nfc.log" "$output/summary.psv"
grep -Fqx 'result=pass' "$output/report.txt"
grep -Fqx -- '--poll' "$output/nfc.log"

if "$RUNNER" --output "$output" >/dev/null 2>&1; then
	printf '%s\n' 'device acceptance unexpectedly overwrote evidence' >&2
	exit 1
fi

printf 'not-oneplus\000' >"$TEST_DIR/wrong-compatible"
bad_output=$TEST_DIR/bad-output
set +e
PMOS_ACCEPT_COMPATIBLE_FILE="$TEST_DIR/wrong-compatible" \
PMOS_ACCEPT_MOBILE_DATA_CHECK="$TEST_DIR/bin/mobile-data" \
PMOS_ACCEPT_AUDIO_CHECK="$TEST_DIR/bin/audio" \
PMOS_ACCEPT_DISPLAY_CHECK="$TEST_DIR/bin/display" \
PMOS_ACCEPT_LOCATION_CHECK="$TEST_DIR/bin/location" \
PMOS_ACCEPT_NFC_CHECK="$TEST_DIR/bin/nfc" \
PMOS_ACCEPT_POWER_CHECK="$TEST_DIR/bin/power" \
PMOS_ACCEPT_WAYDROID_CHECK="$TEST_DIR/bin/waydroid" \
	"$RUNNER" --output "$bad_output" >/dev/null 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -Fqx 'compatibility|1|'"$bad_output/compatibility.log" "$bad_output/summary.psv"
grep -Fqx 'result=fail' "$bad_output/report.txt"

printf '%s\n' 'device acceptance tests passed'
