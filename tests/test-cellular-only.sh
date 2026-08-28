#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROBE=$ROOT/scripts/test-cellular-only
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cellular-only-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

BIN=$TEST_DIR/bin
STATE=$TEST_DIR/wifi.state
LOG=$TEST_DIR/actions.log
UUID1=11111111-2222-3333-4444-555555555555
UUID2=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
mkdir -p "$BIN"

make_fixture() {
	name=$1
	shift
	path=$BIN/$name
	{
		printf '%s\n' '#!/bin/sh'
		printf '%s\n' 'set -eu'
		printf '%s\n' "$@"
	} >"$path"
	chmod 0755 "$path"
}

make_fixture nmcli \
	'case "$*" in' \
	'"radio wifi") cat "$PMOS_TEST_WIFI_STATE" ;;' \
	'"-t -f UUID,TYPE connection show --active")' \
	'  [ "${PMOS_TEST_ACTIVE_QUERY_FAIL:-no}" != yes ] || exit 1' \
	'  printf "%s:802-11-wireless\\n" $PMOS_TEST_WIFI_UUIDS ;;' \
	'"radio wifi off")' \
	'  [ "${PMOS_TEST_REQUIRE_ELEVATION:-no}" != yes ] || [ "${PMOS_TEST_ELEVATED:-no}" = yes ]' \
	'  printf "%s\\n" "radio wifi off" >>"$PMOS_TEST_ACTION_LOG"' \
	'  printf "%s\\n" disabled >"$PMOS_TEST_WIFI_STATE"' \
	'  [ "${PMOS_TEST_WIFI_OFF_FAIL:-no}" != yes ] ;;' \
	'"radio wifi on")' \
	'  [ "${PMOS_TEST_REQUIRE_ELEVATION:-no}" != yes ] || [ "${PMOS_TEST_ELEVATED:-no}" = yes ]' \
	'  printf "%s\\n" "radio wifi on" >>"$PMOS_TEST_ACTION_LOG"' \
	'  [ "${PMOS_TEST_WIFI_ON_FAIL:-no}" != yes ] || exit 1' \
	'  printf "%s\\n" enabled >"$PMOS_TEST_WIFI_STATE" ;;' \
	'--wait\ 30\ connection\ up\ uuid\ *)' \
	'  [ "${PMOS_TEST_REQUIRE_ELEVATION:-no}" != yes ] || [ "${PMOS_TEST_ELEVATED:-no}" = yes ]' \
	'  printf "%s\\n" "$*" >>"$PMOS_TEST_ACTION_LOG"' \
	'  [ "${PMOS_TEST_WIFI_UP_FAIL:-no}" != yes ] ;;' \
	'*) printf "unexpected nmcli arguments: %s\\n" "$*" >&2; exit 2 ;;' \
	'esac'

make_fixture ip \
	'case "$*" in' \
	'"-4 route get 1.1.1.1") printf "%s\\n" "1.1.1.1 dev ${PMOS_TEST_DEFAULT_IFACE:-qmapmux0.0} src 10.0.0.2" ;;' \
	'"-6 route get 2606:4700:4700::1111") exit 1 ;;' \
	'*) printf "unexpected ip arguments: %s\\n" "$*" >&2; exit 2 ;;' \
	'esac'

make_fixture mobile-check \
	'[ "${PMOS_TEST_MOBILE_FAIL:-no}" != yes ] || { printf "%s\\n" "mobile=failure"; exit 1; }' \
	'printf "%s\\n" "gsm_device=cdc-wdm0" "connection=test-data" "data_interface=qmapmux0.0" "ipv4_ping=ok" "dns=ok" "https=ok"'

make_fixture resolvectl \
	'[ "$*" = "query postmarketos.org" ]' \
	'[ "${PMOS_TEST_DNS_FAIL:-no}" != yes ]'

make_fixture getent \
	'[ "$*" = "ahosts postmarketos.org" ]' \
	'[ "${PMOS_TEST_DNS_FAIL:-no}" != yes ]' \
	'printf "%s\\n" "192.0.2.1 STREAM postmarketos.org"'

make_fixture curl \
	'[ "${PMOS_TEST_HTTPS_FAIL:-no}" != yes ] || exit 1' \
	'printf "%s" "${PMOS_TEST_HTTP_CODE:-200}"'

make_fixture waydroid \
	'case "$1" in' \
	'status) printf "%s\\n" "Session: RUNNING" "Container: RUNNING" ;;' \
	'shell) printf "%s\\n" "$*" >>"$PMOS_TEST_ACTION_LOG" ;;' \
	'*) exit 2 ;;' \
	'esac'

make_fixture sudo \
	'[ "$1" != -v ] || { [ "${PMOS_TEST_SUDO_FAIL:-no}" != yes ]; exit; }' \
	'PMOS_TEST_ELEVATED=yes; export PMOS_TEST_ELEVATED' \
	'exec "$@"'

make_fixture sleep ':'

run_probe() {
	PMOS_CELLULAR_ONLY_NMCLI=$BIN/nmcli \
	PMOS_CELLULAR_ONLY_IP=$BIN/ip \
	PMOS_CELLULAR_ONLY_CURL=$BIN/curl \
	PMOS_CELLULAR_ONLY_RESOLVECTL="${PMOS_TEST_RESOLVECTL:-$BIN/resolvectl}" \
	PMOS_CELLULAR_ONLY_GETENT=$BIN/getent \
	PMOS_CELLULAR_ONLY_WAYDROID=$BIN/waydroid \
	PMOS_CELLULAR_ONLY_SUDO=$BIN/sudo \
	PMOS_CELLULAR_ONLY_SLEEP=$BIN/sleep \
	PMOS_CELLULAR_ONLY_MOBILE_CHECK=$BIN/mobile-check \
	PMOS_CELLULAR_ONLY_UID="${PMOS_TEST_UID:-1000}" \
	PMOS_TEST_WIFI_STATE=$STATE \
	PMOS_TEST_ACTION_LOG=$LOG \
	PMOS_TEST_WIFI_UUIDS="$UUID1 $UUID2" \
		sh "$PROBE" "$@"
}

printf '%s\n' enabled >"$STATE"
: >"$LOG"
PMOS_TEST_REQUIRE_ELEVATION=yes run_probe --with-waydroid --wait-seconds 10 \
	>"$TEST_DIR/pass.out"
grep -Fqx 'wifi_initial=enabled' "$TEST_DIR/pass.out"
grep -Fqx 'wifi_disable=pass' "$TEST_DIR/pass.out"
grep -Fqx 'native_default_interface=qmapmux0.0' "$TEST_DIR/pass.out"
grep -Fqx 'native_dns_method=resolvectl' "$TEST_DIR/pass.out"
grep -Fqx 'native_dns=pass' "$TEST_DIR/pass.out"
grep -Fqx 'native_https=200' "$TEST_DIR/pass.out"
grep -Fqx 'waydroid_ipv4=pass' "$TEST_DIR/pass.out"
grep -Fqx 'waydroid_dns=pass' "$TEST_DIR/pass.out"
grep -Fqx 'wifi_restore=pass' "$TEST_DIR/pass.out"
grep -Fqx 'result=pass' "$TEST_DIR/pass.out"
[ "$(cat "$STATE")" = enabled ]
sed -n '1p' "$LOG" | grep -Fqx 'radio wifi off'
sed -n '2p' "$LOG" | grep -Fqx 'shell ping -c 3 -W 3 1.1.1.1'
sed -n '3p' "$LOG" | grep -Fqx 'shell ping -c 1 -W 5 postmarketos.org'
sed -n '4p' "$LOG" | grep -Fqx 'radio wifi on'
sed -n '5p' "$LOG" | grep -Fqx -- "--wait 30 connection up uuid $UUID1"
sed -n '6p' "$LOG" | grep -Fqx -- "--wait 30 connection up uuid $UUID2"

printf '%s\n' enabled >"$STATE"
: >"$LOG"
set +e
PMOS_TEST_MOBILE_FAIL=yes run_probe >"$TEST_DIR/mobile-fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -Fqx 'wifi_restore=pass' "$TEST_DIR/mobile-fail.out"
[ "$(cat "$STATE")" = enabled ]
grep -Fqx 'radio wifi off' "$LOG"
grep -Fqx 'radio wifi on' "$LOG"

printf '%s\n' enabled >"$STATE"
: >"$LOG"
set +e
PMOS_TEST_WIFI_OFF_FAIL=yes run_probe --wait-seconds 10 \
	>"$TEST_DIR/off-fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -Fqx 'wifi_restore=pass' "$TEST_DIR/off-fail.out"
[ "$(cat "$STATE")" = enabled ]
sed -n '1p' "$LOG" | grep -Fqx 'radio wifi off'
sed -n '2p' "$LOG" | grep -Fqx 'radio wifi on'

printf '%s\n' disabled >"$STATE"
: >"$LOG"
run_probe --wait-seconds 10 >"$TEST_DIR/disabled.out"
grep -Fqx 'wifi_disable=already-disabled' "$TEST_DIR/disabled.out"
grep -Fqx 'wifi_restore=not-required' "$TEST_DIR/disabled.out"
grep -Fqx 'result=pass' "$TEST_DIR/disabled.out"
[ "$(cat "$STATE")" = disabled ]
[ ! -s "$LOG" ]

printf '%s\n' disabled >"$STATE"
: >"$LOG"
PMOS_TEST_RESOLVECTL=$BIN/not-installed run_probe --wait-seconds 10 \
	>"$TEST_DIR/getent.out"
grep -Fqx 'native_dns_method=getent' "$TEST_DIR/getent.out"
grep -Fqx 'result=pass' "$TEST_DIR/getent.out"

printf '%s\n' enabled >"$STATE"
: >"$LOG"
set +e
PMOS_TEST_WIFI_ON_FAIL=yes run_probe --wait-seconds 10 \
	>"$TEST_DIR/restore-fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -Fqx 'wifi_restore=fail' "$TEST_DIR/restore-fail.out"

printf '%s\n' enabled >"$STATE"
: >"$LOG"
set +e
PMOS_TEST_ACTIVE_QUERY_FAIL=yes run_probe --wait-seconds 10 \
	>"$TEST_DIR/query-fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'could not read active NetworkManager connections' \
	"$TEST_DIR/query-fail.out"
[ "$(cat "$STATE")" = enabled ]
[ ! -s "$LOG" ]

printf '%s\n' enabled >"$STATE"
: >"$LOG"
set +e
PMOS_TEST_SUDO_FAIL=yes run_probe --with-waydroid --wait-seconds 10 \
	>"$TEST_DIR/sudo-fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'could not validate sudo before the cellular-only test' \
	"$TEST_DIR/sudo-fail.out"
[ "$(cat "$STATE")" = enabled ]
[ ! -s "$LOG" ]

printf '%s\n' enabled >"$STATE"
: >"$LOG"
set +e
PMOS_TEST_SUDO_FAIL=yes run_probe --wait-seconds 10 \
	>"$TEST_DIR/native-sudo-fail.out" 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -q 'could not validate sudo before the cellular-only test' \
	"$TEST_DIR/native-sudo-fail.out"
[ "$(cat "$STATE")" = enabled ]
[ ! -s "$LOG" ]

if run_probe --wait-seconds 9 >/dev/null 2>&1; then
	printf '%s\n' 'invalid wait unexpectedly passed' >&2
	exit 1
fi

stage=$TEST_DIR/stage
make -s -C "$ROOT" install DESTDIR="$stage" PREFIX=/usr >/dev/null
[ -x "$stage/usr/libexec/oneplus6t-pmos-fixes/scripts/test-cellular-only" ]
[ -L "$stage/usr/sbin/pmos-test-cellular-only" ]
[ "$(readlink "$stage/usr/sbin/pmos-test-cellular-only")" = \
	/usr/libexec/oneplus6t-pmos-fixes/scripts/test-cellular-only ]

# Invoke through an installed-style absolute symlink without overriding the
# sibling mobile checker. This catches $0-based lookup under /usr/sbin.
installed_root=$TEST_DIR/installed-layout
mkdir -p "$installed_root/libexec/scripts" "$installed_root/bin"
cp "$PROBE" "$installed_root/libexec/scripts/test-cellular-only"
cp "$BIN/mobile-check" "$installed_root/libexec/scripts/check-mobile-data"
ln -s "$installed_root/libexec/scripts/test-cellular-only" \
	"$installed_root/bin/pmos-test-cellular-only"
printf '%s\n' disabled >"$STATE"
: >"$LOG"
PMOS_CELLULAR_ONLY_NMCLI=$BIN/nmcli \
PMOS_CELLULAR_ONLY_IP=$BIN/ip \
PMOS_CELLULAR_ONLY_CURL=$BIN/curl \
PMOS_CELLULAR_ONLY_RESOLVECTL=$BIN/resolvectl \
PMOS_CELLULAR_ONLY_GETENT=$BIN/getent \
PMOS_CELLULAR_ONLY_WAYDROID=$BIN/waydroid \
PMOS_CELLULAR_ONLY_SUDO=$BIN/sudo \
PMOS_CELLULAR_ONLY_SLEEP=$BIN/sleep \
PMOS_CELLULAR_ONLY_UID=1000 \
PMOS_TEST_WIFI_STATE=$STATE \
PMOS_TEST_ACTION_LOG=$LOG \
PMOS_TEST_WIFI_UUIDS="$UUID1 $UUID2" \
	"$installed_root/bin/pmos-test-cellular-only" --wait-seconds 10 \
	>"$TEST_DIR/installed-layout.out"
grep -Fqx 'connection=test-data' "$TEST_DIR/installed-layout.out"
grep -Fqx 'result=pass' "$TEST_DIR/installed-layout.out"

printf '%s\n' 'cellular-only tests passed'
