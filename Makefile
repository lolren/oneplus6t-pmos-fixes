PREFIX ?= /usr/local
LIBEXECDIR ?= $(PREFIX)/libexec/oneplus6t-pmos-fixes
SBINDIR ?= $(PREFIX)/sbin
DOCDIR ?= $(PREFIX)/share/doc/oneplus6t-pmos-fixes
INSTALL ?= install

SCRIPTS = \
	scripts/configure-mobile-data \
	scripts/remove-mobile-data \
	scripts/check-mobile-data \
	scripts/configure-time-sync

.PHONY: all test install

all: test

test:
	sh -n $(SCRIPTS) tests/test-apn-selection.sh packaging/APKBUILD
	./tests/test-apn-selection.sh

install:
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/scripts"
	$(INSTALL) -d "$(DESTDIR)$(LIBEXECDIR)/data"
	$(INSTALL) -d "$(DESTDIR)$(SBINDIR)"
	$(INSTALL) -d "$(DESTDIR)$(DOCDIR)"
	$(INSTALL) -m 0755 $(SCRIPTS) "$(DESTDIR)$(LIBEXECDIR)/scripts/"
	$(INSTALL) -m 0644 data/mvno-apns.psv "$(DESTDIR)$(LIBEXECDIR)/data/"
	$(INSTALL) -m 0644 README.md CONTRIBUTING.md docs/*.md "$(DESTDIR)$(DOCDIR)/"
	$(INSTALL) -m 0644 packaging/README.md "$(DESTDIR)$(DOCDIR)/PACKAGING.md"
	ln -sfn "$(LIBEXECDIR)/scripts/configure-mobile-data" "$(DESTDIR)$(SBINDIR)/pmos-configure-mobile-data"
	ln -sfn "$(LIBEXECDIR)/scripts/remove-mobile-data" "$(DESTDIR)$(SBINDIR)/pmos-remove-mobile-data"
	ln -sfn "$(LIBEXECDIR)/scripts/check-mobile-data" "$(DESTDIR)$(SBINDIR)/pmos-check-mobile-data"
	ln -sfn "$(LIBEXECDIR)/scripts/configure-time-sync" "$(DESTDIR)$(SBINDIR)/pmos-configure-time-sync"
