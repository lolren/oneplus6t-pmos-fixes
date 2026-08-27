# OnePlus 6T daily-use setup

`configure-daily-use` is the short, reproducible entry point for the three
small runtime configurations that are useful on every postmarketOS install:

1. a NetworkManager mobile-data profile selected from the standard provider
   database plus the reviewed GID-aware MVNO overlay, with a bounded
   stale-bearer watchdog when its packaged unit is present;
2. systemd network-time synchronization; and
3. the optional PipeWire/WirePlumber user service that pairs the built-in
   microphone with the current earpiece, speakerphone or headset route.

It does not install packages, change the camera stack, modify Waydroid, touch
boot files or reboot the phone. The underlying helpers remain independently
reversible and are still the authoritative implementation for each subsystem.

## Install

From a checkout, run the test suite and stage the scripts:

```sh
make test
sudo make install PREFIX=/usr/local
```

The package Makefile installs the same command as
`/usr/sbin/pmos-configure-daily-use` when `PREFIX=/usr` is used.

## Preview and apply

The default is a dry-run. It performs the carrier selection check and prints
the time/audio actions without changing them:

```sh
pmos-configure-daily-use
```

Review the selected provider and then apply:

```sh
pmos-configure-daily-use --apply
pmos-check-mobile-data
pmos-check-audio-routing
timedatectl show -p NTP -p NTPSynchronized -p Timezone
```

The command must be run as the normal graphical login user so that its
privileged subcommands can use `sudo` while the audio service is enabled on
the user's D-Bus session. If no graphical user session exists, apply the
individual mobile/time helpers as root and enable the audio unit later from
that user's session.

The mobile helper enables `oneplus6t-mobile-data-watchdog.timer` only after its
candidate profile has connected and become the managed UUID. The timer ignores
ordinary inactive state, defers during calls and repairs only an activated
profile whose reported QMAP interface/address/default route has disappeared.

## Carrier selection

The mobile-data part uses this order:

- an explicit `--apn`, when supplied;
- an exact MCC/MNC plus SIM GID1/GID2 rule in `data/mvno-apns.psv`;
- a unique GID1 match in `mobile-broadband-provider-info`; or
- an unambiguous NetworkManager provider-database record.

For the Smarty UK SIM described in the project evidence, the matching rule is
MCC/MNC `23420`, GID1 `0309`, APN `mob.asm.net`, IPv4. Other carriers are
selected from the database; ambiguous shared operator codes are refused rather
than silently using another MVNO's APN. A carrier-specific fallback can be
previewed with:

```sh
pmos-configure-daily-use --dry-run \
  --provider 'Carrier name' --apn example.apn
```

Only the managed profile is removed by the matching rollback command:

```sh
sudo pmos-remove-mobile-data
```

## Component rollback

The wrapper does not pretend the three subsystems form one atomic transaction.
If a later component fails, the earlier component is left in its normal
managed state and can be reversed independently:

- cellular: `sudo pmos-remove-mobile-data` (also disables its watchdog timer);
- time: `sudo timedatectl set-ntp false` or the site's normal time policy; and
- audio: `systemctl --user disable --now oneplus6t-audio-route.service`.

The wrapper never enables the optional Waydroid location service. Native GNSS
must be accepted first, and that service remains a separate explicit action as
documented in [LOCATION.md](LOCATION.md).
