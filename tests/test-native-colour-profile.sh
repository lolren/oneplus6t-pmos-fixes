#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROFILE_DIR=$ROOT/config/libcamera/simple

fail() {
	printf '%s\n' "native colour-profile test: $1" >&2
	exit 1
}

check_profile() {
	file=$1
	expected_count=$2
	sentinel=$3

	[ -f "$PROFILE_DIR/$file" ] || fail "missing $file"
	count=$(grep -c '^[[:space:]]*-[[:space:]]*ct:' "$PROFILE_DIR/$file")
	[ "$count" = "$expected_count" ] ||
		fail "$file has $count colour-temperature entries (expected $expected_count)"

	awk -v expected="$expected_count" '
	/^[[:space:]]*-[[:space:]]*ct:/ {
		ct = $3 + 0
		if (seen && ct <= previous)
			exit 1
		previous = ct
		seen++
	}
	END { exit !(seen == expected) }
	' "$PROFILE_DIR/$file" || fail "$file colour temperatures are not strictly increasing"

	grep -Fq "$sentinel" "$PROFILE_DIR/$file" ||
		fail "$file does not contain its sensor-specific profile"
	if grep -Fq 'ccm: [ 1, 0, 0,' "$PROFILE_DIR/$file"; then
		fail "$file still contains the identity colour matrix"
	fi
}

check_profile imx371.yaml 13 '1.87925, -0.0746165, -0.804633'
check_profile imx376.yaml 1 '1.7858, -0.7494, -0.0364'
check_profile imx519.yaml 6 '1.4905, -0.545645, 0.0551411'

printf '%s\n' 'Native sensor colour profiles and package-source invariants passed'
