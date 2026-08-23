#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
CONFIGURE=$PROJECT_DIR/scripts/configure-mobile-data
FIXTURE=$TEST_DIR/fixtures/serviceproviders.xml
OVERLAY=$PROJECT_DIR/data/mvno-apns.psv
OVERLAP_FIXTURE=$TEST_DIR/fixtures/mvno-overlap.psv

run_dry() {
	PMOS_PROVIDER_DB=$FIXTURE PMOS_MVNO_OVERLAY=$OVERLAY \
		"$CONFIGURE" --dry-run "$@"
}

smarty=$(run_dry --operator-code 23420 --gid1 0309)
printf '%s\n' "$smarty" | grep -q '^selection=mvno-overlay$'
printf '%s\n' "$smarty" | grep -q '^provider=SMARTY$'
printf '%s\n' "$smarty" | grep -q '^apn=mob.asm.net$'
printf '%s\n' "$smarty" | grep -q '^ip_mode=ipv4$'
printf '%s\n' "$smarty" | grep -q '^auto_config=no$'

specific=$(PMOS_PROVIDER_DB=$FIXTURE PMOS_MVNO_OVERLAY=$OVERLAP_FIXTURE \
	"$CONFIGURE" --dry-run --operator-code 23420 --gid1 0309)
printf '%s\n' "$specific" | grep -q '^provider=SMARTY$'
printf '%s\n' "$specific" | grep -q '^apn=mob.asm.net$'

if ambiguous=$(run_dry --operator-code 23420 --gid1 FFFF 2>&1); then
	printf 'ambiguous operator unexpectedly succeeded\n' >&2
	exit 1
fi
printf '%s\n' "$ambiguous" | grep -q 'refusing ambiguous automatic APN selection'

unique=$(run_dry --operator-code 310260)
printf '%s\n' "$unique" | grep -q '^selection=provider-database$'
printf '%s\n' "$unique" | grep -q '^provider=Unique Carrier$'
printf '%s\n' "$unique" | grep -q '^auto_config=yes$'

explicit=$(run_dry --provider Test --apn internet.example)
printf '%s\n' "$explicit" | grep -q '^selection=explicit$'
printf '%s\n' "$explicit" | grep -q '^apn=internet.example$'

explicit_v4=$(run_dry --provider Test --apn internet.example --ip-mode ipv4)
printf '%s\n' "$explicit_v4" | grep -q '^ip_mode=ipv4$'

if invalid_mode=$(run_dry --provider Test --apn internet.example --ip-mode invalid 2>&1); then
	printf 'invalid IP mode unexpectedly succeeded\n' >&2
	exit 1
fi
printf '%s\n' "$invalid_mode" | grep -q -- '--ip-mode must be'

if missing_db=$(PMOS_PROVIDER_DB=$TEST_DIR/fixtures/not-present.xml \
	PMOS_MVNO_OVERLAY=$OVERLAY "$CONFIGURE" --dry-run \
	--operator-code 99999 2>&1); then
	printf 'missing provider database unexpectedly succeeded\n' >&2
	exit 1
fi
printf '%s\n' "$missing_db" | grep -q 'provider database not found'

printf 'APN selection tests passed\n'
