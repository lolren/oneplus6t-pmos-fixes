# Native and Waydroid location

The OnePlus 6T postmarketOS location path has two separate parts:

1. native GeoClue must receive a real GNSS or modem fix; and
2. Waydroid must be given a location provider that Android applications can
   consume.

They must not be conflated with Wi-Fi or IP geolocation. An approximate result
such as a nearby town proves only that a network fallback answered; it does not
prove that the phone's GNSS receiver has a fix.

## Native source checks

The standard GeoClue configuration already enables its ModemManager-GPS,
3GPP, CDMA and Wi-Fi sources. It also supports the `/var/run/gps-share.sock`
NMEA socket. Do not create a static `/etc/geolocation` file for a moving phone:
that source is intentionally static and can mask a real GNSS result.

After the phone is responsive, inspect the source without changing it:

```sh
pmos-check-location --output /private/path/oneplus6t-location.txt
```

The report discovers the current ModemManager modem instead of assuming that
its numeric ID is stable, records `--location-status` and `--location-get`,
checks GeoClue and lists NetworkManager devices. It never enables GPS or
changes a refresh rate. The report's `native_fix=coordinates-present` is a
useful prerequisite, not proof of a stable outdoor fix. The underlying
commands can still be inspected directly when needed:

```sh
mmcli -L
mmcli -m 0 --location-status
mmcli -m 0 --location-get
systemctl is-active geoclue.service
```

If the modem exposes GPS NMEA, enable it explicitly and watch for a fix:

```sh
mmcli -m 0 --location-enable-gps-nmea
mmcli -m 0 --location-set-gps-refresh-rate=1
mmcli -m 0 --location-monitor
```

The modem number is discovered from `mmcli -L`; it is not stable and must not
be hard-coded into a patch. A valid NMEA GGA/RMC sentence or a ModemManager
GPS location is the native acceptance evidence. Only after that succeeds
should Wi-Fi fallback be disabled for a “GNSS-only” test.

## Waydroid bridge

Waydroid does not provide a native host-GNSS bridge in the reference image.
`waydroid-location-bridge.py` is therefore an explicit diagnostic bridge. It
accepts ModemManager NMEA or gpsd JSON TPV fixes and injects them into Android's
documented test-provider API.

The default is harmless dry-run mode. It prints the exact commands and never
changes the modem or Waydroid:

```sh
pmos-waydroid-location-bridge \
  --input /private/path/one-fix.nmea \
  --once
```

For a live ModemManager source, after native GNSS has been accepted and the
Waydroid container is healthy:

```sh
pmos-waydroid-location-bridge \
  --source mmcli \
  --enable-gps \
  --apply
```

If gpsd already owns and decodes the receiver, use:

```sh
pmos-waydroid-location-bridge --source gpspipe --apply
```

`--apply` is required before the script can enable GPS or call `waydroid`.
The default provider is `fused`; use `--provider gps` only when the Android
image's location service explicitly requires that provider. The bridge cleans
up a test provider that it created when it exits.

This path is intentionally labeled a mock provider. Android exposes test
locations as mock locations, and some Google Play or anti-spoofing clients may
reject them. It can make Maps-like applications display a host fix, but it is
not yet equivalent to a vendor GNSS HAL. A future full solution requires an
Android location HAL or a reviewed Waydroid framework integration.

## Acceptance

Record all of the following privately after recovery:

- the native `mmcli --location-status` and `--location-get` evidence;
- a fresh GeoClue client result with the phone outdoors and a stable fix;
- `waydroid shell cmd location is-location-enabled` and `dumpsys location`;
- one bridge-injected fix in the Android location log; and
- the behavior of a normal Android map application, including whether it
  reports a mock-location warning.

No coordinates, modem identifiers or location logs belong in Git.

The report is installed by the project Makefile as
`/usr/sbin/pmos-check-location`. Its fixture-driven test runs without a modem
and verifies that coordinate fields are distinguished from a missing native
fix.

Background: the [OnePlus 6T postmarketOS status page](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29)
currently lists GPS as partial, and Waydroid's upstream
[host GPS request](https://github.com/waydroid/waydroid/issues/226) remains a
separate integration problem. The Android command syntax used here follows
the [AOSP location shell implementation](https://android.googlesource.com/platform/frameworks/base/+/master/services/core/java/com/android/server/location/LocationShellCommand.java).
