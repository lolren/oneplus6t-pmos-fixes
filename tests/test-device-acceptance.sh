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

for check in mobile-data cellular-only audio display location nfc power waydroid; do
	make_check "$check"
done

output=$TEST_DIR/output
PMOS_ACCEPT_COMPATIBLE_FILE="$TEST_DIR/compatible" \
PMOS_ACCEPT_MOBILE_DATA_CHECK="$TEST_DIR/bin/mobile-data" \
PMOS_ACCEPT_CELLULAR_ONLY_CHECK="$TEST_DIR/bin/cellular-only" \
PMOS_ACCEPT_AUDIO_CHECK="$TEST_DIR/bin/audio" \
PMOS_ACCEPT_DISPLAY_CHECK="$TEST_DIR/bin/display" \
PMOS_ACCEPT_LOCATION_CHECK="$TEST_DIR/bin/location" \
PMOS_ACCEPT_NFC_CHECK="$TEST_DIR/bin/nfc" \
PMOS_ACCEPT_POWER_CHECK="$TEST_DIR/bin/power" \
PMOS_ACCEPT_WAYDROID_CHECK="$TEST_DIR/bin/waydroid" \
	"$RUNNER" --output "$output" --nfc-poll --cellular-only-waydroid

grep -Fqx 'compatibility|0|'"$output/compatibility.log" "$output/summary.psv"
grep -Fqx 'nfc|0|'"$output/nfc.log" "$output/summary.psv"
grep -Fqx 'cellular-only|0|'"$output/cellular-only.log" "$output/summary.psv"
grep -Fqx 'result=pass' "$output/report.txt"
grep -Fqx -- '--poll' "$output/nfc.log"
grep -Fqx -- '--with-waydroid' "$output/cellular-only.log"

if "$RUNNER" --output "$output" >/dev/null 2>&1; then
	printf '%s\n' 'device acceptance unexpectedly overwrote evidence' >&2
	exit 1
fi

printf 'not-oneplus\000' >"$TEST_DIR/wrong-compatible"
bad_output=$TEST_DIR/bad-output
set +e
PMOS_ACCEPT_COMPATIBLE_FILE="$TEST_DIR/wrong-compatible" \
PMOS_ACCEPT_MOBILE_DATA_CHECK="$TEST_DIR/bin/mobile-data" \
PMOS_ACCEPT_CELLULAR_ONLY_CHECK="$TEST_DIR/bin/cellular-only" \
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
[ ! -e "$bad_output/cellular-only.log" ]

# Public commands are absolute symlinks into libexec. Verify that sibling
# checks and the packaged camera validator are found from the resolved target.
installed_root=$TEST_DIR/installed-layout
installed_scripts=$installed_root/libexec/scripts
mkdir -p "$installed_scripts" "$installed_root/bin"
cp "$RUNNER" "$installed_scripts/run-device-acceptance"
cp "$TEST_DIR/bin/mobile-data" "$installed_scripts/check-mobile-data"
cp "$TEST_DIR/bin/audio" "$installed_scripts/check-audio-routing"
cp "$TEST_DIR/bin/display" "$installed_scripts/check-display"
cp "$TEST_DIR/bin/location" "$installed_scripts/check-location"
cp "$TEST_DIR/bin/nfc" "$installed_scripts/check-nfc"
cp "$TEST_DIR/bin/power" "$installed_scripts/check-power"
cp "$TEST_DIR/bin/waydroid" "$installed_scripts/check-waydroid-health"
cp "$TEST_DIR/bin/mobile-data" "$installed_scripts/validate-pipewire-af.sh"
ln -s "$installed_scripts/run-device-acceptance" \
	"$installed_root/bin/pmos-run-device-acceptance"
installed_output=$TEST_DIR/installed-output
PMOS_ACCEPT_COMPATIBLE_FILE="$TEST_DIR/compatible" \
	"$installed_root/bin/pmos-run-device-acceptance" \
	--output "$installed_output" --with-camera >/dev/null
grep -Fqx 'result=pass' "$installed_output/report.txt"
grep -Fqx "camera|0|$installed_output/camera.log" \
	"$installed_output/summary.psv"

printf '%s\n' 'device acceptance tests passed'
