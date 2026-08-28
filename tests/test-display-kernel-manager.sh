#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MANAGER=$ROOT/scripts/manage-display-kernel
MOCK_APK=$ROOT/tests/fixtures/display-kernel-bin/apk
R10_MANIFEST=$ROOT/data/kernel-r8-r10.psv
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/display-kernel-manager-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

grep -q '^generation|oneplus6t-venus-safety-r8-r10$' "$R10_MANIFEST"
grep -q '^candidate|linux-postmarketos-qcom-sdm845|7.1_rc1-r10|aarch64|.*|f5b3c8fa795b63718eebab9f2adbc0bee7545d2b147d5a0f3c1ae63c8176597e$' \
	"$R10_MANIFEST"
grep -q '^rollback|linux-postmarketos-qcom-sdm845|7.1_rc1-r8|aarch64|.*|232d6cdef5ed4c16a86c6ab0c50446a465571e996a6af49683da02716e32d98e$' \
	"$R10_MANIFEST"
grep -q 'data/kernel-r8-r10.psv' "$ROOT/Makefile"

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

installed_root=$TEST_ROOT/installed-layout
installed_scripts=$installed_root/libexec/scripts
mkdir -p "$installed_scripts" "$installed_root/libexec/data" \
	"$installed_root/bin"
cp "$MANAGER" "$installed_scripts/manage-display-kernel"
cp "$manifest" "$installed_root/libexec/data/display-kernel-r8-r9.psv"
ln -s "$installed_scripts/manage-display-kernel" \
	"$installed_root/bin/pmos-manage-display-kernel"
installed_status=$(PATH="$ROOT/tests/fixtures/display-kernel-bin:/usr/bin:/bin" \
	PMOS_DISPLAY_APK="$MOCK_APK" \
	PMOS_DISPLAY_COMPATIBLE_FILE="$compatible" \
	PMOS_DISPLAY_SUDO=env \
	PMOS_DISPLAY_WORLD="$world" \
	PMOS_DISPLAY_MOCK_STATE="$state" \
	"$installed_root/bin/pmos-manage-display-kernel" status)
printf '%s\n' "$installed_status" | grep -q '^generation=test-display-r8-r9$'
printf '%s\n' "$installed_status" | grep -q '^state=rollback$'

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
printf '%s\n' "$applied" | grep -q '^boot_image_update=package-trigger$'
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

unset PMOS_DISPLAY_MOCK_SIGNATURE_FAILURE
printf '%s\n' '7.1_rc1-r8' >"$state"
PMOS_DISPLAY_MOCK_UID=0
PMOS_DISPLAY_MOCK_APK_LOG=$TEST_ROOT/root-apk.log
export PMOS_DISPLAY_MOCK_UID PMOS_DISPLAY_MOCK_APK_LOG
root_simulation=$(run_manager --evidence "$TEST_ROOT/root-simulation" install)
printf '%s\n' "$root_simulation" | grep -q '^mode=simulation$'
grep -q '^initdb|' "$PMOS_DISPLAY_MOCK_APK_LOG"
if grep -q -- '--usermode' "$PMOS_DISPLAY_MOCK_APK_LOG"; then
	printf '%s\n' 'root repository verification unexpectedly used --usermode' >&2
	exit 1
fi

printf '%s\n' 'display kernel manager tests passed'
