#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MANIFEST=$ROOT/data/camera-generation-r34-r36.psv
KEY=$ROOT/packaging/keys/pmos@local-6a92d930.rsa.pub

fail() {
	printf '%s\n' "camera release manifest test: $1" >&2
	exit 1
}

[ -f "$MANIFEST" ] || fail 'missing r34/r36 manifest'
[ -f "$KEY" ] || fail 'missing current release public key'
[ "$(sha256sum "$KEY" | awk '{ print $1 }')" = \
	c1f8892b9576ce1807732a985243311d272ab422fc30958a2fb78d5bfc8d36a6 ] || \
	fail 'release public-key hash changed'

grep -Fxq 'schema|1' "$MANIFEST" || fail 'unsupported manifest schema'
grep -Fxq 'generation|oneplus6t-r34-r36' "$MANIFEST" || \
	fail 'wrong generation name'
grep -Fxq 'compatible|oneplus,fajita' "$MANIFEST" || \
	fail 'wrong device compatibility'
grep -Fxq 'signing-key|pmos@local-6a92d930.rsa.pub|c1f8892b9576ce1807732a985243311d272ab422fc30958a2fb78d5bfc8d36a6' \
	"$MANIFEST" || fail 'wrong signing-key row'

for channel in candidate rollback; do
	count=$(awk -F '|' -v channel="$channel" \
		'$1 == channel { count++ } END { print count + 0 }' "$MANIFEST")
	[ "$count" -eq 5 ] || fail "$channel has $count package rows"
done

awk -F '|' '
	$1 == "candidate" || $1 == "rollback" {
		if ($2 == "") exit 1
		if ($3 == "") exit 1
		if ($4 != "aarch64" && $4 != "noarch") exit 1
		if ($5 !~ /^[^\/ |]+\.apk$/) exit 1
		if ($6 !~ /^[0-9a-f]{64}$/) exit 1
		key = $1 SUBSEP $2
		if (seen[key]++) exit 1
		rows++
	}
	END { exit !(rows == 10) }
' "$MANIFEST" || fail 'malformed or duplicate package rows'

grep -Fxq 'candidate|libcamera|99990.7.2-r34|aarch64|libcamera-99990.7.2-r34.apk|7e241928daaab4ed285160b1ea6d89d758f92783851093ec406d7c3590b450b3' "$MANIFEST" || fail 'candidate libcamera pin changed'
grep -Fxq 'rollback|libcamera|99990.7.2-r33|aarch64|libcamera-99990.7.2-r33.apk|76808314599b548a86c2924aaea82b98ce0a913a38967acfd32cd95b54684f6d' "$MANIFEST" || fail 'rollback libcamera pin changed'

printf '%s\n' 'Camera r34/r36 release manifest tests passed'
