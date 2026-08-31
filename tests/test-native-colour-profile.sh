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
	profile_kind=${4:-calibrated}

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
	[ "$profile_kind" = green_corrected ] ||
		fail "$file test must name its colour profile kind"
	grep -Fq 'ccm: [ 0.90, 0.10, 0.0,' "$PROFILE_DIR/$file" ||
		fail "$file does not contain the measured green-correction matrix"
	grep -Fq '0.10, 0.80, 0.10,' "$PROFILE_DIR/$file" ||
		fail "$file does not contain the green-correction centre row"
	grep -Fq '0.0, 0.10, 0.90 ]' "$PROFILE_DIR/$file" ||
		fail "$file does not contain the green-correction blue row"
	if grep -Fq 'ccm: [ 1, 0, 0,' "$PROFILE_DIR/$file"; then
		fail "$file still contains the uncorrected identity colour matrix"
	fi
}

check_profile imx371.yaml 1 'ccm: [ 0.90, 0.10, 0.0,' green_corrected
check_profile imx376.yaml 1 'ccm: [ 0.90, 0.10, 0.0,' green_corrected
check_profile imx519.yaml 1 'ccm: [ 0.90, 0.10, 0.0,' green_corrected

printf '%s\n' 'Native sensor colour profiles and package-source invariants passed'
