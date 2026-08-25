#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
MANAGER=$ROOT/scripts/manage-camera-generation
MOCK_BIN=$TEST_DIR/fixtures/camera-generation-bin
MOCK_SMOKE=$TEST_DIR/fixtures/camera-generation-smoke
TEST_ROOT=$(mktemp -d)
trap 'rm -r -- "$TEST_ROOT"' EXIT HUP INT TERM

stage=$TEST_ROOT/stage
keys=$TEST_ROOT/keys
state=$TEST_ROOT/packages.psv
world=$TEST_ROOT/world
compatible=$TEST_ROOT/compatible
systemctl_log=$TEST_ROOT/systemctl.log
smoke_log=$TEST_ROOT/smoke.log
manifest=$TEST_ROOT/generation.psv

mkdir -p "$stage/candidate/aarch64" "$stage/candidate/noarch" \
	"$stage/rollback/aarch64" "$stage/rollback/noarch" "$keys"
: >"$stage/candidate/aarch64/APKINDEX.tar.gz"
: >"$stage/rollback/aarch64/APKINDEX.tar.gz"
printf '%s\n' 'candidate pipewire r7' >"$stage/candidate/aarch64/pipewire-spa-libcamera-1.6.8-r7.apk"
printf '%s\n' 'candidate app r1' >"$stage/candidate/aarch64/advanced-snapshot-0.1.0-r1.apk"
printf '%s\n' 'candidate lang r1' >"$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r1.apk"
printf '%s\n' 'rollback pipewire r6' >"$stage/rollback/aarch64/pipewire-spa-libcamera-1.6.8-r6.apk"
printf '%s\n' 'rollback app r0' >"$stage/rollback/aarch64/advanced-snapshot-0.1.0-r0.apk"
printf '%s\n' 'rollback lang r0' >"$stage/rollback/noarch/advanced-snapshot-lang-0.1.0-r0.apk"
printf '%s\n' 'mock public key' >"$keys/mock.rsa.pub"
printf '%s\n' 'oneplus,fajita' >"$compatible"

hash_file() {
	sha256sum "$1" | awk '{ print $1 }'
}

{
	printf '%s\n' 'schema|1' 'generation|test-r7-r1' 'compatible|oneplus,fajita'
	printf 'signing-key|mock.rsa.pub|%s\n' "$(hash_file "$keys/mock.rsa.pub")"
	printf 'candidate|pipewire-spa-libcamera|1.6.8-r7|aarch64|pipewire-spa-libcamera-1.6.8-r7.apk|%s\n' \
		"$(hash_file "$stage/candidate/aarch64/pipewire-spa-libcamera-1.6.8-r7.apk")"
	printf 'candidate|advanced-snapshot|0.1.0-r1|aarch64|advanced-snapshot-0.1.0-r1.apk|%s\n' \
		"$(hash_file "$stage/candidate/aarch64/advanced-snapshot-0.1.0-r1.apk")"
	printf 'candidate|advanced-snapshot-lang|0.1.0-r1|noarch|advanced-snapshot-lang-0.1.0-r1.apk|%s\n' \
		"$(hash_file "$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r1.apk")"
	printf 'rollback|pipewire-spa-libcamera|1.6.8-r6|aarch64|pipewire-spa-libcamera-1.6.8-r6.apk|%s\n' \
		"$(hash_file "$stage/rollback/aarch64/pipewire-spa-libcamera-1.6.8-r6.apk")"
	printf 'rollback|advanced-snapshot|0.1.0-r0|aarch64|advanced-snapshot-0.1.0-r0.apk|%s\n' \
		"$(hash_file "$stage/rollback/aarch64/advanced-snapshot-0.1.0-r0.apk")"
	printf 'rollback|advanced-snapshot-lang|0.1.0-r0|noarch|advanced-snapshot-lang-0.1.0-r0.apk|%s\n' \
		"$(hash_file "$stage/rollback/noarch/advanced-snapshot-lang-0.1.0-r0.apk")"
} >"$manifest"

set_rollback_state() {
	printf '%s\n' \
		'pipewire-spa-libcamera|1.6.8-r6' \
		'advanced-snapshot|0.1.0-r0' \
		'advanced-snapshot-lang|0.1.0-r0' >"$state"
	printf '%s\n' \
		'base-package' \
		'advanced-snapshot><mock-r0' \
		'advanced-snapshot-lang><mock-r0-lang' | sort >"$world"
}

run_manager() {
	PATH="$MOCK_BIN:/usr/bin:/bin" \
	PMOS_CAMERA_WORLD="$world" \
	PMOS_CAMERA_COMPATIBLE_FILE="$compatible" \
	PMOS_CAMERA_SUDO=sudo \
	PMOS_MOCK_PACKAGE_STATE="$state" \
	PMOS_MOCK_WORLD="$world" \
	PMOS_MOCK_INDEX="$stage/candidate/aarch64/APKINDEX.tar.gz" \
	PMOS_MOCK_SYSTEMCTL_LOG="$systemctl_log" \
	PMOS_MOCK_SMOKE_LOG="$smoke_log" \
		"$MANAGER" --stage "$stage" --manifest "$manifest" \
		--keys-dir "$keys" --smoke-test "$MOCK_SMOKE" "$@"
}

set_rollback_state
: >"$systemctl_log"
: >"$smoke_log"
initial_world_hash=$(hash_file "$world")

status=$(run_manager status)
printf '%s\n' "$status" | grep -q '^state=rollback$'

install_sim=$(run_manager --evidence "$TEST_ROOT/install-sim" install)
printf '%s\n' "$install_sim" | grep -q '^mode=simulation$'
printf '%s\n' "$install_sim" | grep -q '^transitions=3$'
[ "$(hash_file "$world")" = "$initial_world_hash" ]
grep -q '^advanced-snapshot|0.1.0-r0$' "$state"

install_apply=$(run_manager --evidence "$TEST_ROOT/install-apply" --apply install)
printf '%s\n' "$install_apply" | grep -q '^state=candidate$'
grep -q '^pipewire-spa-libcamera|1.6.8-r7$' "$state"
grep -q '^advanced-snapshot|0.1.0-r1$' "$state"
grep -q '^advanced-snapshot><mock-r1$' "$world"
! grep -q '^pipewire-spa-libcamera' "$world"
tail -n 1 "$smoke_log" | grep -q '^required$'
grep -q 'stop xdg-desktop-portal.service' "$systemctl_log"
grep -q 'start xdg-desktop-portal.service' "$systemctl_log"
grep -q 'xdg-desktop-portal-wlr.service' "$systemctl_log"

candidate_world_hash=$(hash_file "$world")
rollback_sim=$(run_manager --evidence "$TEST_ROOT/rollback-sim" rollback)
printf '%s\n' "$rollback_sim" | grep -q '^mode=simulation$'
[ "$(hash_file "$world")" = "$candidate_world_hash" ]
grep -q '^advanced-snapshot|0.1.0-r1$' "$state"

rollback_apply=$(run_manager --evidence "$TEST_ROOT/rollback-apply" --apply rollback)
printf '%s\n' "$rollback_apply" | grep -q '^state=rollback$'
grep -q '^pipewire-spa-libcamera|1.6.8-r6$' "$state"
grep -q '^advanced-snapshot|0.1.0-r0$' "$state"
[ "$(hash_file "$world")" = "$initial_world_hash" ]
tail -n 1 "$smoke_log" | grep -q '^accepted$'
grep -q 'not removed due to' "$TEST_ROOT/rollback-apply/rollback.unpin.simulation.log"

printf '%s\n' \
	'pipewire-spa-libcamera|1.6.8-r6' \
	'advanced-snapshot|0.1.0-r1' \
	'advanced-snapshot-lang|0.1.0-r0' >"$state"
if run_manager --evidence "$TEST_ROOT/mixed" install >/dev/null 2>&1; then
	printf '%s\n' 'mixed package generation unexpectedly passed' >&2
	exit 1
fi

set_rollback_state
PMOS_MOCK_UNEXPECTED_OPERATION=yes; export PMOS_MOCK_UNEXPECTED_OPERATION
if run_manager --evidence "$TEST_ROOT/unexpected" install >/dev/null 2>&1; then
	printf '%s\n' 'unexpected apk operation was not rejected' >&2
	exit 1
fi
unset PMOS_MOCK_UNEXPECTED_OPERATION

PMOS_MOCK_MUTATE_INDEX=yes; export PMOS_MOCK_MUTATE_INDEX
if run_manager --evidence "$TEST_ROOT/index-race" install >/dev/null 2>&1; then
	printf '%s\n' 'repository index race unexpectedly passed' >&2
	exit 1
fi
unset PMOS_MOCK_MUTATE_INDEX
: >"$stage/candidate/aarch64/APKINDEX.tar.gz"

printf '%s\n' 'tamper' >>"$stage/candidate/aarch64/advanced-snapshot-0.1.0-r1.apk"
if run_manager --evidence "$TEST_ROOT/tampered" install >/dev/null 2>&1; then
	printf '%s\n' 'tampered candidate unexpectedly passed' >&2
	exit 1
fi

# A UI-only generation must retain an already accepted PipeWire package and
# require exactly the two app-package transitions in both directions.
stage=$TEST_ROOT/stage-static-pipewire
state=$TEST_ROOT/packages-static-pipewire.psv
world=$TEST_ROOT/world-static-pipewire
manifest=$TEST_ROOT/generation-static-pipewire.psv
mkdir -p "$stage/candidate/aarch64" "$stage/candidate/noarch" \
	"$stage/rollback/aarch64" "$stage/rollback/noarch"
: >"$stage/candidate/aarch64/APKINDEX.tar.gz"
: >"$stage/rollback/aarch64/APKINDEX.tar.gz"
printf '%s\n' 'accepted pipewire r7' \
	>"$stage/candidate/aarch64/pipewire-spa-libcamera-1.6.8-r7.apk"
printf '%s\n' 'accepted pipewire r7' \
	>"$stage/rollback/aarch64/pipewire-spa-libcamera-1.6.8-r7.apk"
printf '%s\n' 'candidate app r2' \
	>"$stage/candidate/aarch64/advanced-snapshot-0.1.0-r2.apk"
printf '%s\n' 'candidate lang r2' \
	>"$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r2.apk"
printf '%s\n' 'rollback app r1' \
	>"$stage/rollback/aarch64/advanced-snapshot-0.1.0-r1.apk"
printf '%s\n' 'rollback lang r1' \
	>"$stage/rollback/noarch/advanced-snapshot-lang-0.1.0-r1.apk"

{
	printf '%s\n' 'schema|1' 'generation|test-r7-r2' 'compatible|oneplus,fajita'
	printf 'signing-key|mock.rsa.pub|%s\n' "$(hash_file "$keys/mock.rsa.pub")"
	printf 'candidate|pipewire-spa-libcamera|1.6.8-r7|aarch64|pipewire-spa-libcamera-1.6.8-r7.apk|%s\n' \
		"$(hash_file "$stage/candidate/aarch64/pipewire-spa-libcamera-1.6.8-r7.apk")"
	printf 'candidate|advanced-snapshot|0.1.0-r2|aarch64|advanced-snapshot-0.1.0-r2.apk|%s\n' \
		"$(hash_file "$stage/candidate/aarch64/advanced-snapshot-0.1.0-r2.apk")"
	printf 'candidate|advanced-snapshot-lang|0.1.0-r2|noarch|advanced-snapshot-lang-0.1.0-r2.apk|%s\n' \
		"$(hash_file "$stage/candidate/noarch/advanced-snapshot-lang-0.1.0-r2.apk")"
	printf 'rollback|pipewire-spa-libcamera|1.6.8-r7|aarch64|pipewire-spa-libcamera-1.6.8-r7.apk|%s\n' \
		"$(hash_file "$stage/rollback/aarch64/pipewire-spa-libcamera-1.6.8-r7.apk")"
	printf 'rollback|advanced-snapshot|0.1.0-r1|aarch64|advanced-snapshot-0.1.0-r1.apk|%s\n' \
		"$(hash_file "$stage/rollback/aarch64/advanced-snapshot-0.1.0-r1.apk")"
	printf 'rollback|advanced-snapshot-lang|0.1.0-r1|noarch|advanced-snapshot-lang-0.1.0-r1.apk|%s\n' \
		"$(hash_file "$stage/rollback/noarch/advanced-snapshot-lang-0.1.0-r1.apk")"
} >"$manifest"

printf '%s\n' \
	'pipewire-spa-libcamera|1.6.8-r7' \
	'advanced-snapshot|0.1.0-r1' \
	'advanced-snapshot-lang|0.1.0-r1' >"$state"
printf '%s\n' \
	'base-package' \
	'advanced-snapshot><mock-r1' \
	'advanced-snapshot-lang><mock-r1-lang' | sort >"$world"
: >"$systemctl_log"
: >"$smoke_log"

PMOS_MOCK_CANDIDATE_PIPEWIRE_VERSION=1.6.8-r7
PMOS_MOCK_ROLLBACK_PIPEWIRE_VERSION=1.6.8-r7
PMOS_MOCK_CANDIDATE_APP_VERSION=0.1.0-r2
PMOS_MOCK_ROLLBACK_APP_VERSION=0.1.0-r1
PMOS_MOCK_CANDIDATE_LANG_VERSION=0.1.0-r2
PMOS_MOCK_ROLLBACK_LANG_VERSION=0.1.0-r1
export PMOS_MOCK_CANDIDATE_PIPEWIRE_VERSION PMOS_MOCK_ROLLBACK_PIPEWIRE_VERSION \
	PMOS_MOCK_CANDIDATE_APP_VERSION PMOS_MOCK_ROLLBACK_APP_VERSION \
	PMOS_MOCK_CANDIDATE_LANG_VERSION PMOS_MOCK_ROLLBACK_LANG_VERSION

static_world_hash=$(hash_file "$world")
static_status=$(run_manager status)
printf '%s\n' "$static_status" | grep -q '^state=rollback$'
static_install_sim=$(run_manager --evidence "$TEST_ROOT/static-install-sim" install)
printf '%s\n' "$static_install_sim" | grep -q '^transitions=2$'
[ "$(hash_file "$world")" = "$static_world_hash" ]

static_install=$(run_manager --evidence "$TEST_ROOT/static-install" --apply install)
printf '%s\n' "$static_install" | grep -q '^state=candidate$'
grep -q '^pipewire-spa-libcamera|1.6.8-r7$' "$state"
grep -q '^advanced-snapshot|0.1.0-r2$' "$state"
grep -q '^advanced-snapshot><mock-r2$' "$world"
! grep -q '^pipewire-spa-libcamera' "$world"
tail -n 1 "$smoke_log" | grep -q '^required$'

static_candidate_world_hash=$(hash_file "$world")
static_rollback_sim=$(run_manager --evidence "$TEST_ROOT/static-rollback-sim" rollback)
printf '%s\n' "$static_rollback_sim" | grep -q '^transitions=2$'
[ "$(hash_file "$world")" = "$static_candidate_world_hash" ]

static_rollback=$(run_manager --evidence "$TEST_ROOT/static-rollback" --apply rollback)
printf '%s\n' "$static_rollback" | grep -q '^state=rollback$'
grep -q '^pipewire-spa-libcamera|1.6.8-r7$' "$state"
grep -q '^advanced-snapshot|0.1.0-r1$' "$state"
[ "$(hash_file "$world")" = "$static_world_hash" ]
! grep -q '^pipewire-spa-libcamera' "$world"
[ ! -e "$TEST_ROOT/static-rollback/rollback.unpin.simulation.log" ]
tail -n 1 "$smoke_log" | grep -q '^accepted$'

unset PMOS_MOCK_CANDIDATE_PIPEWIRE_VERSION PMOS_MOCK_ROLLBACK_PIPEWIRE_VERSION \
	PMOS_MOCK_CANDIDATE_APP_VERSION PMOS_MOCK_ROLLBACK_APP_VERSION \
	PMOS_MOCK_CANDIDATE_LANG_VERSION PMOS_MOCK_ROLLBACK_LANG_VERSION

printf '%s\n' 'Camera generation manager tests passed'
