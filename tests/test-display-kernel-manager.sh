#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MANAGER=$ROOT/scripts/manage-display-kernel
MOCK_APK=$ROOT/tests/fixtures/display-kernel-bin/apk
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/display-kernel-manager-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

stage=$TEST_ROOT/stage
keys=$TEST_ROOT/keys
state=$TEST_ROOT/state
world=$TEST_ROOT/world
compatible=$TEST_ROOT/compatible
manifest=$TEST_ROOT/display.psv
mkdir -p "$stage/candidate/aarch64" "$stage/rollback/aarch64" "$keys"

printf '%s\n' 'signed candidate index' >"$stage/candidate/aarch64/APKINDEX.tar.gz"
printf '%s\n' 'signed rollback index' >"$stage/rollback/aarch64/APKINDEX.tar.gz"
printf '%s\n' 'candidate kernel package' \
	>"$stage/candidate/aarch64/linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk"
printf '%s\n' 'rollback kernel package' \
	>"$stage/rollback/aarch64/linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk"
printf '%s\n' 'mock public key' >"$keys/mock.rsa.pub"
printf 'oneplus,fajita\0' >"$compatible"
printf '%s\n' 'base-package' >"$world"
printf '%s\n' '7.1_rc1-r8' >"$state"

hash_file() {
	sha256sum "$1" | awk '{ print $1 }'
}

{
	printf '%s\n' 'schema|1' 'generation|test-display-r8-r9' 'compatible|oneplus,fajita'
	printf 'signing-key|mock.rsa.pub|%s\n' "$(hash_file "$keys/mock.rsa.pub")"
	printf 'candidate|linux-postmarketos-qcom-sdm845|7.1_rc1-r9|aarch64|linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk|%s\n' \
		"$(hash_file "$stage/candidate/aarch64/linux-postmarketos-qcom-sdm845-7.1_rc1-r9.apk")"
	printf 'rollback|linux-postmarketos-qcom-sdm845|7.1_rc1-r8|aarch64|linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk|%s\n' \
		"$(hash_file "$stage/rollback/aarch64/linux-postmarketos-qcom-sdm845-7.1_rc1-r8.apk")"
} >"$manifest"

run_manager() {
	PATH="$ROOT/tests/fixtures/display-kernel-bin:/usr/bin:/bin" \
	PMOS_DISPLAY_APK="$MOCK_APK" \
	PMOS_DISPLAY_COMPATIBLE_FILE="$compatible" \
	PMOS_DISPLAY_SUDO=env \
	PMOS_DISPLAY_WORLD="$world" \
	PMOS_DISPLAY_MOCK_STATE="$state" \
		"$MANAGER" --stage "$stage" --manifest "$manifest" \
		--keys-dir "$keys" "$@"
}

status=$(run_manager status)
printf '%s\n' "$status" | grep -q '^installed_version=7.1_rc1-r8$'
printf '%s\n' "$status" | grep -q '^state=rollback$'

before=$(hash_file "$world")
simulation=$(run_manager --evidence "$TEST_ROOT/install-simulation" install)
printf '%s\n' "$simulation" | grep -q '^mode=simulation$'
printf '%s\n' "$simulation" | grep -q '^target_version=7.1_rc1-r9$'
[ "$(cat "$state")" = '7.1_rc1-r8' ]
[ "$(hash_file "$world")" = "$before" ]

applied=$(run_manager --evidence "$TEST_ROOT/install-apply" --apply install)
printf '%s\n' "$applied" | grep -q '^state=candidate$'
printf '%s\n' "$applied" | grep -q '^manual_reboot_required=yes$'
[ "$(cat "$state")" = '7.1_rc1-r9' ]

rollback=$(run_manager --evidence "$TEST_ROOT/rollback-apply" --apply rollback)
printf '%s\n' "$rollback" | grep -q '^state=rollback$'
[ "$(cat "$state")" = '7.1_rc1-r8' ]

PMOS_DISPLAY_MOCK_SIGNATURE_FAILURE=yes
export PMOS_DISPLAY_MOCK_SIGNATURE_FAILURE
if run_manager --evidence "$TEST_ROOT/signature-failure" install \
	>"$TEST_ROOT/signature-failure.log" 2>&1; then
	printf '%s\n' 'signature failure unexpectedly passed' >&2
	exit 1
fi
grep -Fq 'package signature verification failed' "$TEST_ROOT/signature-failure.log"

printf '%s\n' 'display kernel manager tests passed'
