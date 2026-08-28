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
mmcli -m 0 --location-enable-gps-raw --location-enable-gps-nmea
mmcli -m 0 --location-set-gps-refresh-rate=1
mmcli -m 0 --location-monitor
```

The modem number is discovered from `mmcli -L`; it is not stable and must not
be hard-coded into a patch. A valid NMEA GGA/RMC sentence or a ModemManager
GPS location is the native acceptance evidence. Only after that succeeds
should Wi-Fi fallback be disabled for a “GNSS-only” test.

The reference phone advertises both `agps-msa` and `agps-msb`, but on the
2026-08-27 live test each mode failed in the Qualcomm/ModemManager path with
`Failed to receive operation mode indication`. The bridge deliberately does
not keep retrying those modes: raw and NMEA GNSS continue to work, while a
firmware or ModemManager fix is still needed for assisted GNSS. An indoor
stream showing RMC `V`, GGA quality `0` and GSA mode `1` is a healthy receiver
without a satellite fix, not a usable position.

## Waydroid bridge

Waydroid does not provide a native host-GNSS bridge in the reference image.
`waydroid-location-bridge.py` is therefore an explicit diagnostic bridge. It
accepts raw ModemManager NMEA, ModemManager's formatted decimal GPS records, or
gpsd JSON TPV fixes and injects them into Android's documented test-provider
API. On the reference SDM845, `mmcli --location-monitor` remains silent even
when location signaling is temporarily enabled, while
`--location-get --output-keyvalue` updates normally. The live bridge therefore
polls that read-only snapshot once per second and refuses to emit a fix until
the NMEA UTC field advances. This both works around the missing signal and
prevents a cached coordinate from being replayed as live. GGA is processed
before RMC so Android receives its HDOP-derived accuracy when both are present.
The parser keeps latitude and longitude from the same formatted update together.

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

Current Waydroid releases require `waydroid shell --` before Android command
options. Android also gates `cmd location providers` with the
`android:mock_location` app-op even though `waydroid shell` enters as root.
The bridge handles both details: it records the prior UID-0 app-op mode,
uses appops' required `set --uid 0` form, verifies that the mode actually
became `allow`, and restores the exact prior mode during normal or interrupted
cleanup. It also treats a Java exception as failure even when Waydroid's shell
wrapper returns status zero. Every injected fix receives a current Android
timestamp.

For an optional continuous service, enable it only after the native GNSS and
Waydroid health checks have passed:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now oneplus6t-waydroid-location.service
```

The unit runs the same ModemManager bridge with `--enable-gps` and the Android
`fused` test provider. It is installed disabled and, once explicitly enabled,
starts and stops with `waydroid-container.service`; it does not force Waydroid
to run merely for GNSS. It restarts after a temporary modem/source failure and
uses `SIGINT` on stop so the bridge can disable and remove a provider it
created. Stop it before changing the Waydroid image:

```sh
sudo systemctl disable --now oneplus6t-waydroid-location.service
```

Runtime r25 treats Vanilla Android's `No operations / Default mode: deny`
app-op output as the normal default state. It snapshots the modem's enabled
location sources and GPS refresh interval, enables only missing sources, and
restores both values on every exit. The unit waits 30 seconds between failures
and permits only six starts per ten minutes. This prevents an incompatible
Android response from becoming the five-second CPU/GNSS restart loop found
during the 2026-08-28 power audit. Continuous one-second GNSS still has a real
battery cost, so leave the service disabled unless Waydroid location is needed.

This remains a mock-provider integration. It does not provide a vendor GNSS
HAL, and applications that reject mock locations may still refuse the fix.

The Android shell interface accepts latitude/longitude, accuracy and time for
each injected location. The bridge therefore does not advertise or fabricate
altitude, speed or bearing support; parsed altitude is retained only as source
metadata. This prevents clients from being promised fields that this bridge
cannot populate. Applied-mode logs record source, accuracy and success but omit
the exact coordinates; dry-run output still shows the command it would execute.

This path is intentionally labeled a mock provider. Android exposes test
locations as mock locations, and some Google Play or anti-spoofing clients may
reject them. It can make Maps-like applications display a host fix, but it is
not yet equivalent to a vendor GNSS HAL. A future full solution requires an
Android location HAL or a reviewed Waydroid framework integration.

If a map displays an old town while `dumpsys location` reports `last
location=null` for passive, network and fused providers, that town is app,
account or IP-geolocation cache—not a current Android OS fix. Do not hard-code
the expected town or inject guessed coordinates. Wait for a valid native RMC
`A`, positive GGA quality, or ModemManager decimal fix.

## Reference-phone live status (2026-08-28)

- the inserted SMARTY SIM registered at home on 3 UK LTE and packet service
  attached;
- the active `mob.asm.net` bearer supplied address, gateway and DNS settings,
  four packets forced through its QMAP interface completed with no loss, and
  cellular-only DNS plus HTTPS passed while Wi-Fi was temporarily disabled;
- after the SIM was reinserted, restarting raw/NMEA collection produced a
  changing one-second UTC stream, positive GGA quality and active RMC; the
  private coordinates fall within 5 km of Stroud and GPS UTC-of-day matches
  the synchronized host clock;
- the former Reading result is therefore retained only as evidence of stale
  network/account/IP fallback, not as a GNSS coordinate;
- the Waydroid service is enabled and accepted with `fused provider [mock]`,
  repeated fresh GGA injections at 3.5 m estimated accuracy and a private
  Android fix within 5 km of Stroud; no map package was installed for an
  application-level check; and
- a live stop/start rollback test removed the override, restored the original
  fused provider and restored the mock-location app-op to `default` before
  cleanly starting again.

No coordinate, modem identifier, phone number or SIM identifier from that
acceptance run is stored in this repository.

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
`/usr/sbin/pmos-check-location`. The bridge's fixture-driven tests run without
a modem and verify raw NMEA, gpsd JSON, formatted ModemManager coordinates,
record-boundary handling, and the missing-fix path.

Background: the [OnePlus 6T postmarketOS status page](https://wiki.postmarketos.org/wiki/OnePlus_6T_%28oneplus-fajita%29)
currently lists GPS as partial, and Waydroid's upstream
[host GPS request](https://github.com/waydroid/waydroid/issues/226) remains a
separate integration problem. The Android command syntax used here follows
the [AOSP location shell implementation](https://android.googlesource.com/platform/frameworks/base/+/master/services/core/java/com/android/server/location/LocationShellCommand.java).
