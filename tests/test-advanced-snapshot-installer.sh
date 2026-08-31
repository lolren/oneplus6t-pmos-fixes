#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER=$ROOT/scripts/install-advanced-snapshot

[ -x "$INSTALLER" ] || {
	printf '%s\n' 'Advanced Snapshot installer is not executable' >&2
	exit 1
}

sh -n "$INSTALLER"
help=$($INSTALLER --help)
printf '%s\n' "$help" | grep -q -- '--apply'
printf '%s\n' "$help" | grep -q -- '--work-dir'
printf '%s\n' "$help" | grep -q 'simulation-only'

grep -Fqx 'REPOSITORY=lolren/advanced-snapshot' "$INSTALLER"
grep -Fqx 'RELEASE_TAG=r38-fresh-still-autofocus' "$INSTALLER"
grep -Fqx 'MAIN_APK=advanced-snapshot-0.1.0-r38.apk' "$INSTALLER"
grep -Fqx 'LANG_APK=advanced-snapshot-lang-0.1.0-r38.apk' "$INSTALLER"
grep -Fqx 'SIGNING_KEY=pmos@local-6a92d930.rsa.pub' "$INSTALLER"
grep -Fq -- 'SIGNING_KEY_SHA256=c1f8892b9576ce1807732a985243311d272ab422fc30958a2fb78d5bfc8d36a6' "$INSTALLER"
if grep -Fq -- 'https://github.com/' "$INSTALLER" &&
	grep -Fq -- 'http://' "$INSTALLER"; then
	printf '%s\n' 'Advanced Snapshot installer contains an insecure HTTP URL' >&2
	exit 1
fi
grep -Fq -- 'https://github.com/$REPOSITORY/releases/download/$RELEASE_TAG' "$INSTALLER"
grep -Fq -- 'sha256sum -c "$CHECKSUMS"' "$INSTALLER"
grep -Fq -- '--keys-dir "$keys_dir" verify' "$INSTALLER"
grep -Fq -- 'sudo_command' "$INSTALLER"
grep -Fq -- 'result=simulation' "$INSTALLER"
grep -Fq -- 'result=installed' "$INSTALLER"
if grep -Eq '(^|[[:space:]])rm[[:space:]]+-rf([[:space:]]|$)' "$INSTALLER"; then
	printf '%s\n' 'Advanced Snapshot installer contains broad recursive deletion' >&2
	exit 1
fi

printf '%s\n' 'Advanced Snapshot installer invariants passed'
