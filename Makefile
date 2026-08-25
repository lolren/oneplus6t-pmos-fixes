PREFIX ?= /usr/local
LIBEXECDIR ?= $(PREFIX)/libexec/oneplus6t-pmos-fixes
SBINDIR ?= $(PREFIX)/sbin
DOCDIR ?= $(PREFIX)/share/doc/oneplus6t-pmos-fixes
INSTALL ?= install

SCRIPTS = \
	scripts/configure-mobile-data \
	scripts/remove-mobile-data \
	scripts/check-mobile-data \
	scripts/configure-time-sync \
	scripts/check-messages \
	scripts/manage-camera-generation

PYTHON_SCRIPTS = scripts/v4l2-focus-control.py

HOST_BUILD_SCRIPTS = scripts/build-waydroid-camera

CAMERA_TEST_SCRIPTS = \
	tests/camera/run-light-step.sh \
	tests/camera/validate-pipewire-af.sh

.PHONY: all test install

all: test

test:
	sh -n $(SCRIPTS) $(HOST_BUILD_SCRIPTS) $(CAMERA_TEST_SCRIPTS) \
		tests/fixtures/camera-generation-bin/* \
		tests/fixtures/camera-generation-smoke \
		tests/test-apn-selection.sh tests/test-messages-check.sh \
		tests/test-camera-generation.sh packaging/APKBUILD
	./tests/test-apn-selection.sh
	./tests/test-messages-check.sh
	./tests/test-camera-generation.sh
	python3 tests/test-ppm-metrics.py
	python3 scripts/v4l2-focus-control.py --help >/dev/null

install:
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/scripts"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/data"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/keys"
	$(INSTALL) -d "$(DESTDIR)$(SBINDIR)"
	$(INSTALL) -d "$(DESTDIR)$(DOCDIR)"
	$(INSTALL) -m 0755 $(SCRIPTS) "$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0755 $(PYTHON_SCRIPTS) "$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0755 tests/camera/validate-pipewire-af.sh \
		"$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0644 data/mvno-apns.psv "$(DESTDIR)$(LIBEXECDIR)/data/"
	$(INSTALL) -m 0644 data/camera-generation-r7-r1.psv \
		data/camera-generation-r7-r2.psv \
		"$(DESTDIR)$(LIBEXECDIR)/data/"
	$(INSTALL) -m 0644 packaging/keys/pmos@local-6a8b0868.rsa.pub \
		"$(DESTDIR)$(LIBEXECDIR)/keys/"
	$(INSTALL) -m 0644 README.md CONTRIBUTING.md docs/*.md "$(DESTDIR)$(DOCDIR)/"
	$(INSTALL) -m 0644 packaging/README.md "$(DESTDIR)$(DOCDIR)/PACKAGING.md"
	ln -sfn "$(LIBEXECDIR)/scripts/configure-mobile-data" "$(DESTDIR)$(SBINDIR)/pmos-configure-mobile-data"
	ln -sfn "$(LIBEXECDIR)/scripts/remove-mobile-data" "$(DESTDIR)$(SBINDIR)/pmos-remove-mobile-data"
	ln -sfn "$(LIBEXECDIR)/scripts/check-mobile-data" "$(DESTDIR)$(SBINDIR)/pmos-check-mobile-data"
	ln -sfn "$(LIBEXECDIR)/scripts/configure-time-sync" "$(DESTDIR)$(SBINDIR)/pmos-configure-time-sync"
	ln -sfn "$(LIBEXECDIR)/scripts/check-messages" "$(DESTDIR)$(SBINDIR)/pmos-check-messages"
	ln -sfn "$(LIBEXECDIR)/scripts/manage-camera-generation" \
		"$(DESTDIR)$(SBINDIR)/pmos-manage-camera-generation"
	ln -sfn "$(LIBEXECDIR)/scripts/v4l2-focus-control.py" "$(DESTDIR)$(SBINDIR)/pmos-v4l2-focus-control"
