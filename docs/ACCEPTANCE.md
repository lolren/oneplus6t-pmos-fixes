# Unattended device acceptance

`scripts/run-device-acceptance` is the single entry point for collecting a
repeatable OnePlus 6T postmarketOS health and acceptance run. It keeps one log
per check and a machine-readable `summary.psv`, so a later run can be compared
without relying on terminal scrollback.

The default run checks:

- the device-tree compatible string (`oneplus,fajita`);
- the connected mobile-data bearer and default route;
- PipeWire/WirePlumber audio nodes and current defaults;
- DRM connector/backlight state and filtered display errors;
- ModemManager, GeoClue and NetworkManager location state;
- NFC controller/rfkill and userspace reader availability;
- battery, CPU policy and suspend capabilities; and
- the Waydroid mount/I/O health gate.

The default run is observational. It does not configure the modem, enable
time sync, change power policy, poll NFC, access a Waydroid overlay, reboot or
modify boot state.

## Basic run

Run as the normal graphical login user on the phone:

```sh
mkdir -p "$HOME/oneplus6t-acceptance"
pmos-run-device-acceptance --output "$HOME/oneplus6t-acceptance/run-1"
```

The output directory must be new or empty. A non-zero exit status means that
at least one selected check failed; inspect `report.txt` and the corresponding
`.log` file. A report can contain exact location coordinates, NFC identifiers,
camera serials or display logs and should not be published without review.

## Optional checks

The camera check is intentionally opt-in because it restarts the graphical
user's PipeWire and WirePlumber services and briefly owns the camera:

```sh
pmos-run-device-acceptance \
  --output "$HOME/oneplus6t-acceptance/camera-run" \
  --with-camera --close-camera-apps --stability-seconds 60
```

`--with-messages` launches Chatty and verifies its D-Bus window.
`--with-gapps` checks for the optional Play Store package set. `--nfc-poll`
explicitly invokes the NFC reader and may change its state; use it only when a
tag is available.

The camera run requires the same conditions as
`tests/camera/validate-pipewire-af.sh`: a graphical session, active PipeWire
and WirePlumber, no competing camera stream and the installed matching camera
generation. It produces no image. The camera runner restores the user's
service environment on exit, including interruption.

## Reproducible source checkout

From a source checkout, the equivalent command is:

```sh
./scripts/run-device-acceptance \
  --output /private/path/oneplus6t-acceptance
```

Use the `summary.psv` rows as the stable result boundary. The individual
reports remain authoritative for interpretation; this wrapper does not turn a
diagnostic that reports `unavailable` into a false pass.
