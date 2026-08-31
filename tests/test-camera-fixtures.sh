#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SWEEP=$TEST_DIR/camera/focus-sweep.yaml

[ "$(grep -c '^frames:$' "$SWEEP")" -eq 1 ] || {
	printf '%s\n' 'focus sweep must contain one frames sequence' >&2
	exit 1
}

for entry in \
	'  - 0:' \
	'  - 12:' \
	'  - 24:' \
	'  - 36:' \
	'  - 48:'; do
	grep -q "^$entry$" "$SWEEP" || {
		printf 'missing focus sweep entry: %s\n' "$entry" >&2
		exit 1
	}
done

grep -q '^[[:space:]]*AfMode: 0$' "$SWEEP" || {
	printf '%s\n' 'focus sweep must select manual mode' >&2
	exit 1
}

printf '%s\n' 'camera fixture tests passed'
