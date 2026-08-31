#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT=$ROOT/scripts/enable-ssh
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ssh-recovery-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM

[ -x "$SCRIPT" ]
sh -n "$SCRIPT"
mkdir -p "$TEST_DIR/bin"
ln -s /bin/true "$TEST_DIR/bin/sshd.pam"

systemd_output=$TEST_DIR/systemd.txt
env \
	PMOS_SSH_INIT=systemd \
	PMOS_SSH_SYSTEMCTL=/bin/true \
	PATH="$TEST_DIR/bin:$PATH" \
	"$SCRIPT" --dry-run >"$systemd_output"
grep -Fqx 'report=oneplus6t-ssh-recovery' "$systemd_output"
grep -Fqx 'init=systemd' "$systemd_output"
grep -Fqx 'sshd=present' "$systemd_output"
grep -Fqx 'would-run=systemctl enable --now sshd.service' "$systemd_output"
grep -Fqx 'restart=no' "$systemd_output"
grep -Fqx 'result=dry-run' "$systemd_output"

openrc_output=$TEST_DIR/openrc.txt
env \
	PMOS_SSH_INIT=openrc \
	PMOS_SSH_RC_UPDATE=/bin/true \
	PMOS_SSH_SERVICE=/bin/true \
	PATH="$TEST_DIR/bin:$PATH" \
	"$SCRIPT" --dry-run >"$openrc_output"
grep -Fqx 'init=openrc' "$openrc_output"
grep -Fqx 'would-run=rc-update add sshd default; service sshd start' "$openrc_output"

restart_systemd_output=$TEST_DIR/restart-systemd.txt
env \
	PMOS_SSH_INIT=systemd \
	PMOS_SSH_SYSTEMCTL=/bin/true \
	PATH="$TEST_DIR/bin:$PATH" \
	"$SCRIPT" --dry-run --restart >"$restart_systemd_output"
grep -Fqx 'restart=yes' "$restart_systemd_output"
grep -Fqx 'would-run=systemctl enable sshd.service; systemctl restart sshd.service' \
	"$restart_systemd_output"

restart_openrc_output=$TEST_DIR/restart-openrc.txt
env \
	PMOS_SSH_INIT=openrc \
	PMOS_SSH_RC_UPDATE=/bin/true \
	PMOS_SSH_SERVICE=/bin/true \
	PATH="$TEST_DIR/bin:$PATH" \
	"$SCRIPT" --dry-run --restart >"$restart_openrc_output"
grep -Fqx 'restart=yes' "$restart_openrc_output"
grep -Fqx 'would-run=rc-update add sshd default; service sshd restart' \
	"$restart_openrc_output"

stage=$(mktemp -d "${TMPDIR:-/tmp}/ssh-recovery-stage.XXXXXX")
trap 'rm -rf "$TEST_DIR" "$stage"' EXIT HUP INT TERM
make -s -C "$ROOT" install DESTDIR="$stage" PREFIX=/usr >/dev/null
[ -L "$stage/usr/sbin/pmos-enable-ssh" ]
[ -x "$stage/usr/libexec/oneplus6t-pmos-fixes/scripts/enable-ssh" ]

printf '%s\n' 'SSH recovery tests passed'
