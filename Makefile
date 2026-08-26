PREFIX ?= /usr/local
LIBEXECDIR ?= $(PREFIX)/libexec/oneplus6t-pmos-fixes
SBINDIR ?= $(PREFIX)/sbin
DOCDIR ?= $(PREFIX)/share/doc/oneplus6t-pmos-fixes
WIREPLUMBER_DIR ?= $(PREFIX)/share/wireplumber/wireplumber.conf.d
SYSTEMD_USER_DIR ?= $(PREFIX)/lib/systemd/user
SYSTEMD_SYSTEM_DIR ?= $(PREFIX)/lib/systemd/system
INSTALL ?= install

SCRIPTS = \
	scripts/configure-mobile-data \
	scripts/remove-mobile-data \
	scripts/check-mobile-data \
	scripts/configure-time-sync \
	scripts/check-messages \
	scripts/manage-camera-generation \
	scripts/pmos-safe-upgrade \
	scripts/check-power \
	scripts/measure-power \
	scripts/check-nfc \
	scripts/check-location \
	scripts/check-display \
	scripts/manage-display-kernel \
	scripts/check-waydroid-health \
	scripts/check-waydroid-gapps \
	scripts/camera-flash \
	scripts/run-waydroid-camera-probe \
	scripts/compare-waydroid-camera-probes \
	scripts/audio-route-policy \
	scripts/check-audio-routing \
	scripts/run-device-acceptance

PYTHON_SCRIPTS = \
	scripts/v4l2-focus-control.py \
	scripts/waydroid-location-bridge.py

HOST_BUILD_SCRIPTS = \
	scripts/build-waydroid-camera \
	scripts/package-waydroid-camera \
	scripts/install-waydroid-camera

HOST_DIAGNOSTIC_SCRIPTS = \
	scripts/check-device-transport

CAMERA_TEST_SCRIPTS = \
	tests/camera/run-light-step.sh \
	tests/camera/validate-pipewire-af.sh

CAMERA_TEST_PYTHON = \
	tests/camera/analyze-light-step.py \
	tests/camera/capture-portal-screenshot.py \
	tests/camera/ppm-metrics.py \
	tests/camera/uinput-touch.py

.PHONY: all test install

all: test

test:
	sh -n $(SCRIPTS) $(HOST_BUILD_SCRIPTS) $(HOST_DIAGNOSTIC_SCRIPTS) $(CAMERA_TEST_SCRIPTS) \
		tests/fixtures/camera-generation-bin/* \
		 tests/fixtures/camera-generation-smoke \
		tests/fixtures/nfctool \
		 tests/test-apn-selection.sh tests/test-messages-check.sh \
		tests/test-camera-generation.sh tests/test-waydroid-installer.sh \
		tests/test-waydroid-probe-runner.sh \
		tests/test-waydroid-probe-compare.sh \
		tests/test-waydroid-gpu-sync.sh \
		tests/test-waydroid-rgb-preview.sh \
		 tests/test-waydroid-gapps.sh \
		tests/test-display-report.sh \
		tests/test-camera-flash.sh \
		tests/test-device-acceptance.sh \
		tests/test-location-service.sh \
		tests/test-update-guard.sh \
		tests/test-display-kernel-manager.sh \
		packaging/APKBUILD
	./tests/test-apn-selection.sh
	./tests/test-messages-check.sh
	./tests/test-audio-route-policy.sh
	./tests/test-power-report.sh
	./tests/test-power-sampler.sh
	./tests/test-nfc-report.sh
	./tests/test-location-report.sh
	./tests/test-waydroid-health.sh
	./tests/test-camera-generation.sh
	sh tests/test-waydroid-installer.sh
	sh tests/test-waydroid-probe-runner.sh
	sh tests/test-waydroid-probe-compare.sh
	sh tests/test-waydroid-gpu-sync.sh
	sh tests/test-waydroid-rgb-preview.sh
	sh tests/test-waydroid-gapps.sh
	sh tests/test-display-report.sh
	sh tests/test-display-kernel-manager.sh
	./tests/test-camera-flash.sh
	sh tests/test-device-acceptance.sh
	sh tests/test-location-service.sh
	sh tests/test-device-transport.sh
	./tests/test-update-guard.sh
	python3 tests/test-location-bridge.py
	python3 tests/test-ppm-metrics.py
	python3 tests/test-af-reference.py
	python3 -m py_compile $(PYTHON_SCRIPTS) $(CAMERA_TEST_PYTHON)
	python3 scripts/v4l2-focus-control.py --help >/dev/null
	python3 tests/camera/uinput-touch.py --dry-run \
		tap --x 0.50 --y 0.50 >/dev/null
	python3 tests/camera/uinput-touch.py --dry-run \
		pinch --start-span 0.18 --end-span 0.55 >/dev/null

install:
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/scripts"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/data"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/config/libcamera/simple"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/config/waydroid"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/keys"
	$(INSTALL) -d "$(DESTDIR)$(WIREPLUMBER_DIR)"
	$(INSTALL) -d "$(DESTDIR)$(SYSTEMD_USER_DIR)"
	$(INSTALL) -d "$(DESTDIR)$(SYSTEMD_SYSTEM_DIR)"
	$(INSTALL) -d "$(DESTDIR)$(SBINDIR)"
	$(INSTALL) -d "$(DESTDIR)$(DOCDIR)"
	$(INSTALL) -m 0755 $(SCRIPTS) "$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0755 $(PYTHON_SCRIPTS) "$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0755 $(HOST_BUILD_SCRIPTS) "$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0644 config/waydroid/camera_hal.yaml \
		config/waydroid/configuration.yaml \
		config/waydroid/init.zz-oneplus6t-camera.rc.in \
		"$(DESTDIR)$(LIBEXECDIR)/config/waydroid/"
	$(INSTALL) -m 0644 config/libcamera/simple/imx371.yaml \
		config/libcamera/simple/imx376.yaml \
		config/libcamera/simple/imx519.yaml \
		"$(DESTDIR)$(LIBEXECDIR)/config/libcamera/simple/"
	$(INSTALL) -m 0644 config/wireplumber/90-oneplus6t-audio.conf \
		"$(DESTDIR)$(WIREPLUMBER_DIR)/"
	sed 's|@LIBEXEC@|$(LIBEXECDIR)|g' \
		config/systemd/user/oneplus6t-audio-route.service \
		> "$(DESTDIR)$(SYSTEMD_USER_DIR)/oneplus6t-audio-route.service"
	sed 's|@SBINDIR@|$(SBINDIR)|g' \
		config/systemd/oneplus6t-waydroid-location.service \
		> "$(DESTDIR)$(SYSTEMD_SYSTEM_DIR)/oneplus6t-waydroid-location.service"
	$(INSTALL) -m 0755 tests/camera/validate-pipewire-af.sh \
		"$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0644 data/mvno-apns.psv "$(DESTDIR)$(LIBEXECDIR)/data/"
	$(INSTALL) -m 0644 data/display-kernel-r8-r9.psv \
		"$(DESTDIR)$(LIBEXECDIR)/data/"
	$(INSTALL) -m 0644 data/camera-generation-r7-r1.psv \
		data/camera-generation-r7-r2.psv \
		data/camera-generation-r7-r3.psv \
		data/camera-generation-r7-r4.psv \
		data/camera-generation-r7-r5.psv \
		data/camera-generation-r7-r6.psv \
		data/camera-generation-r7-r7.psv \
		data/camera-generation-r7-r10.psv \
		data/camera-generation-r7-r11.psv \
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
	ln -sfn "$(LIBEXECDIR)/scripts/pmos-safe-upgrade" \
		"$(DESTDIR)$(SBINDIR)/pmos-safe-upgrade"
	ln -sfn "$(LIBEXECDIR)/scripts/check-power" \
		"$(DESTDIR)$(SBINDIR)/pmos-check-power"
	ln -sfn "$(LIBEXECDIR)/scripts/measure-power" \
		"$(DESTDIR)$(SBINDIR)/pmos-measure-power"
	ln -sfn "$(LIBEXECDIR)/scripts/check-nfc" \
		"$(DESTDIR)$(SBINDIR)/pmos-check-nfc"
	ln -sfn "$(LIBEXECDIR)/scripts/check-location" \
		"$(DESTDIR)$(SBINDIR)/pmos-check-location"
	ln -sfn "$(LIBEXECDIR)/scripts/check-display" \
		"$(DESTDIR)$(SBINDIR)/pmos-check-display"
	ln -sfn "$(LIBEXECDIR)/scripts/manage-display-kernel" \
		"$(DESTDIR)$(SBINDIR)/pmos-manage-display-kernel"
	ln -sfn "$(LIBEXECDIR)/scripts/camera-flash" \
		"$(DESTDIR)$(SBINDIR)/pmos-camera-flash"
	ln -sfn "$(LIBEXECDIR)/scripts/check-waydroid-health" \
		"$(DESTDIR)$(SBINDIR)/pmos-check-waydroid-health"
	ln -sfn "$(LIBEXECDIR)/scripts/check-waydroid-gapps" \
		"$(DESTDIR)$(SBINDIR)/pmos-check-waydroid-gapps"
	ln -sfn "$(LIBEXECDIR)/scripts/run-waydroid-camera-probe" \
		"$(DESTDIR)$(SBINDIR)/pmos-run-waydroid-camera-probe"
	ln -sfn "$(LIBEXECDIR)/scripts/compare-waydroid-camera-probes" \
		"$(DESTDIR)$(SBINDIR)/pmos-compare-waydroid-camera-probes"
	ln -sfn "$(LIBEXECDIR)/scripts/v4l2-focus-control.py" "$(DESTDIR)$(SBINDIR)/pmos-v4l2-focus-control"
	ln -sfn "$(LIBEXECDIR)/scripts/waydroid-location-bridge.py" \
		"$(DESTDIR)$(SBINDIR)/pmos-waydroid-location-bridge"
	ln -sfn "$(LIBEXECDIR)/scripts/check-audio-routing" "$(DESTDIR)$(SBINDIR)/pmos-check-audio-routing"
	ln -sfn "$(LIBEXECDIR)/scripts/run-device-acceptance" \
		"$(DESTDIR)$(SBINDIR)/pmos-run-device-acceptance"
