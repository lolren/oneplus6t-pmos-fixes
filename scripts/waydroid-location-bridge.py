#!/usr/bin/env python3
"""Bridge host GNSS fixes into a Waydroid test location provider.

The native postmarketOS side is deliberately kept separate from Android.  The
host source can be ModemManager's NMEA monitor or gpsd's JSON stream.  Android
receives fixes through the documented ``cmd location`` test-provider API.  A
test provider is visible to Android as a mock location, so this is a bridge and
diagnostic, not a claim of a real Android GNSS HAL.

The default is dry-run.  ``--apply`` is required before either the host modem
location state or the Waydroid location service is changed.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Optional, Sequence, TextIO


@dataclass(frozen=True)
class LocationFix:
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    altitude: Optional[float] = None
    source: str = "unknown"


def _coordinate(value: str, hemisphere: str, latitude: bool) -> Optional[float]:
    if not value or hemisphere not in ("N", "S", "E", "W"):
        return None
    try:
        degree_digits = 2 if latitude else 3
        degrees = int(value[:degree_digits])
        minutes = float(value[degree_digits:])
    except (ValueError, TypeError):
        return None
    if not 0.0 <= minutes < 60.0:
        return None
    result = degrees + minutes / 60.0
    if hemisphere in ("S", "W"):
        result = -result
    limit = 90.0 if latitude else 180.0
    return result if -limit <= result <= limit else None


def _valid_nmea_checksum(line: str) -> bool:
    if "*" not in line:
        return True
    payload, checksum = line[1:].split("*", 1)
    checksum = checksum[:2]
    if not re.fullmatch(r"[0-9A-Fa-f]{2}", checksum):
        return False
    value = 0
    for character in payload:
        value ^= ord(character)
    return value == int(checksum, 16)


def _nmea_fields(line: str) -> Optional[list[str]]:
    line = line.strip().strip("'\"")
    marker = line.find("$")
    if marker < 0:
        return None
    line = line[marker:].split("\\r", 1)[0].split("\\n", 1)[0]
    if not line.startswith("$") or not _valid_nmea_checksum(line):
        return None
    payload = line[1:].split("*", 1)[0]
    fields = payload.split(",")
    return fields if fields and len(fields[0]) >= 3 else None


def parse_nmea(line: str) -> Optional[LocationFix]:
    """Parse a valid GGA or RMC sentence into a location fix."""

    fields = _nmea_fields(line)
    if fields is None:
        return None
    sentence = fields[0][-3:].upper()
    if sentence == "GGA" and len(fields) >= 10:
        # GGA fix quality 0 means that the receiver has no position fix.
        if not fields[6] or fields[6] == "0":
            return None
        latitude = _coordinate(fields[2], fields[3], latitude=True)
        longitude = _coordinate(fields[4], fields[5], latitude=False)
        if latitude is None or longitude is None:
            return None
        try:
            hdop = float(fields[8]) if fields[8] else None
            altitude = float(fields[9]) if fields[9] else None
        except ValueError:
            hdop = None
            altitude = None
        # HDOP is not a confidence radius, but it is a safer estimate than
        # claiming metre-level precision when only NMEA is available.
        accuracy = max(3.0, hdop * 5.0) if hdop is not None and hdop > 0 else None
        return LocationFix(latitude, longitude, accuracy, altitude, "nmea-gga")

    if sentence == "RMC" and len(fields) >= 7:
        if fields[2].upper() != "A":
            return None
        latitude = _coordinate(fields[3], fields[4], latitude=True)
        longitude = _coordinate(fields[5], fields[6], latitude=False)
        if latitude is None or longitude is None:
            return None
        return LocationFix(latitude, longitude, None, None, "nmea-rmc")

    return None


def parse_gpsd(line: str) -> Optional[LocationFix]:
    """Parse one gpsd JSON TPV record."""

    try:
        record = json.loads(line)
    except (TypeError, ValueError, json.JSONDecodeError):
        return None
    if record.get("class") != "TPV":
        return None
    if record.get("mode", 0) < 2:
        return None
    try:
        latitude = float(record["lat"])
        longitude = float(record["lon"])
    except (KeyError, TypeError, ValueError):
        return None
    if not -90.0 <= latitude <= 90.0 or not -180.0 <= longitude <= 180.0:
        return None
    accuracy_values = []
    for key in ("epx", "epy"):
        try:
            value = float(record[key])
        except (KeyError, TypeError, ValueError):
            continue
        if value > 0:
            accuracy_values.append(value)
    try:
        altitude = float(record["alt"])
    except (KeyError, TypeError, ValueError):
        altitude = None
    return LocationFix(
        latitude,
        longitude,
        max(accuracy_values) if accuracy_values else None,
        altitude,
        "gpsd-tpv",
    )


def parse_location_line(line: str) -> Optional[LocationFix]:
    """Parse one raw NMEA or gpsd JSON line.

    ModemManager's human-readable decimal output is handled by
    :class:`ModemLocationParser`, because its latitude and longitude fields
    are normally printed on separate lines.
    """

    stripped = line.strip()
    if not stripped:
        return None
    if stripped.startswith("{"):
        return parse_gpsd(stripped)
    return parse_nmea(stripped)


_MODEM_LOCATION_FIELD_RE = re.compile(
    r"\b(?P<key>latitude|longitude|altitude|horizontal[\s_-]+accuracy|accuracy)"
    r"\s*:\s*(?P<value>[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)",
    re.IGNORECASE,
)


class ModemLocationParser:
    """Parse raw or formatted records emitted by ModemManager.

    ``mmcli --location-monitor`` can emit raw NMEA sentences, but its
    formatted location records expose decimal latitude and longitude as
    separate ``key: value`` fields.  Keeping the small amount of state here
    lets the live bridge consume either form without making assumptions about
    the modem number or the exact indentation used by ``mmcli``.
    """

    def __init__(self) -> None:
        self._latitude: Optional[float] = None
        self._longitude: Optional[float] = None
        self._accuracy: Optional[float] = None
        self._altitude: Optional[float] = None
        self._seen_coordinates: set[str] = set()

    def _reset(self) -> None:
        self._latitude = None
        self._longitude = None
        self._accuracy = None
        self._altitude = None
        self._seen_coordinates.clear()

    def _field_boundary(self, line: str) -> None:
        """Drop an incomplete record when mmcli starts a new location block."""

        lower = line.lower()
        if re.search(
            r"\b(?:gps|3gpp|cdma)\s+location\b|\blocation\s+updated\b",
            lower,
        ):
            self._reset()

    def feed(self, line: str) -> Optional[LocationFix]:
        """Consume one monitor line and return a complete fix when available."""

        raw_fix = parse_location_line(line)
        if raw_fix is not None:
            self._reset()
            return raw_fix

        self._field_boundary(line)
        matches = list(_MODEM_LOCATION_FIELD_RE.finditer(line))
        if not matches:
            return None

        for match in matches:
            key = re.sub(r"[\s-]+", "_", match.group("key").lower())
            try:
                value = float(match.group("value"))
            except (TypeError, ValueError):
                continue
            if not math.isfinite(value):
                continue

            if key in ("latitude", "longitude"):
                # A repeated coordinate normally marks the next formatted
                # record.  Do not combine a new latitude with an old longitude
                # when a modem omits a field in a transient update.
                if key in self._seen_coordinates:
                    self._reset()
                self._seen_coordinates.add(key)
                if key == "latitude" and -90.0 <= value <= 90.0:
                    self._latitude = value
                elif key == "longitude" and -180.0 <= value <= 180.0:
                    self._longitude = value
            elif key == "altitude":
                self._altitude = value
            elif key in ("accuracy", "horizontal_accuracy") and value > 0:
                self._accuracy = value

        if self._latitude is None or self._longitude is None:
            return None
        fix = LocationFix(
            self._latitude,
            self._longitude,
            self._accuracy,
            self._altitude,
            "modemmanager-gps",
        )
        self._reset()
        return fix


def _run(
    command: Sequence[str], *, dry_run: bool, timeout: float = 10.0
) -> subprocess.CompletedProcess[str]:
    if dry_run:
        print("$ " + shlex.join(command))
        return subprocess.CompletedProcess(command, 0, "", "")
    try:
        result = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"command failed: {shlex.join(command)}: {error}", file=sys.stderr)
        return subprocess.CompletedProcess(command, 1, "", str(error))
    if result.stdout:
        print(result.stdout, end="", file=sys.stderr)
    return result


def discover_modem() -> str:
    result = subprocess.run(
        ["mmcli", "-L"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    modems = re.findall(r"/Modem/(\d+)", result.stdout)
    if result.returncode != 0 or not modems:
        raise RuntimeError("ModemManager did not report a modem")
    return modems[0]


def _modem_lines(modem: str, enable_gps: bool, dry_run: bool) -> Iterator[str]:
    if enable_gps:
        command = [
            "mmcli",
            "-m",
            modem,
            "--location-enable-gps-raw",
            "--location-enable-gps-nmea",
        ]
        if _run(command, dry_run=dry_run).returncode != 0:
            raise RuntimeError("could not enable ModemManager GPS NMEA")
        refresh = ["mmcli", "-m", modem, "--location-set-gps-refresh-rate=1"]
        _run(refresh, dry_run=dry_run)
    if dry_run:
        print("$ " + shlex.join(["mmcli", "-m", modem, "--location-monitor"]))
        return
    process = subprocess.Popen(
        ["mmcli", "-m", modem, "--location-monitor"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    assert process.stdout is not None
    try:
        yield from process.stdout
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()


def _gpsd_lines(dry_run: bool) -> Iterator[str]:
    if dry_run:
        print("$ " + shlex.join(["gpspipe", "-w"]))
        return
    process = subprocess.Popen(
        ["gpspipe", "-w"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    assert process.stdout is not None
    try:
        yield from process.stdout
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()


def input_lines(path: Optional[Path]) -> TextIO | Iterator[str]:
    if path is None:
        return sys.stdin
    return path.open("r", encoding="utf-8")


class WaydroidProvider:
    def __init__(self, provider: str, dry_run: bool) -> None:
        self.provider = provider
        self.dry_run = dry_run
        self.created = False
        self._mock_location_mode: Optional[str] = None
        self._changed_mock_location_mode = False

    def _waydroid_command(self, *arguments: str) -> list[str]:
        # ``--`` is required by current Waydroid releases whenever the
        # Android command has options of its own. Without it, options such as
        # --accuracy are consumed by the host-side Waydroid CLI.
        return ["waydroid", "shell", "--", *arguments]

    def _location_command(self, action: str, *arguments: str) -> list[str]:
        return self._waydroid_command(
            "cmd",
            "location",
            "providers",
            action,
            *arguments,
        )

    def _appops_command(self, action: str, *arguments: str) -> list[str]:
        return self._waydroid_command(
            "cmd",
            "appops",
            action,
            "0",
            "android:mock_location",
            *arguments,
        )

    def _prepare_mock_location_permission(self) -> None:
        """Allow the root identity used by ``waydroid shell`` to inject.

        Android's location shell command is gated by the MOCK_LOCATION app-op,
        including on a rooted Waydroid image. Preserve an existing mode and
        restore it when this bridge exits instead of leaving a broad developer
        setting behind.
        """

        result = _run(self._appops_command("get"), dry_run=self.dry_run)
        if result.returncode != 0:
            raise RuntimeError("could not query Android mock-location app-op")
        match = re.search(
            r"\bMOCK_LOCATION\s*:\s*([a-z_-]+)",
            result.stdout,
            re.IGNORECASE,
        )
        # Dry-run commands have no output. Treat that as the Android default
        # so the complete reversible command sequence is still displayed.
        self._mock_location_mode = match.group(1).lower() if match else "default"
        if self._mock_location_mode == "allow":
            return
        result = _run(
            self._appops_command("set", "allow"),
            dry_run=self.dry_run,
        )
        if result.returncode != 0:
            raise RuntimeError("could not allow Android mock-location app-op")
        self._changed_mock_location_mode = True

    def start(self) -> None:
        if not self.dry_run and shutil.which("waydroid") is None:
            raise RuntimeError("waydroid command is not installed")
        self._prepare_mock_location_permission()
        add = self._location_command(
            "add-test-provider",
            self.provider,
            "--powerRequirement",
            "1",
            "--accuracy",
            "1",
        )
        result = _run(add, dry_run=self.dry_run)
        self.created = result.returncode == 0
        enabled = self._location_command(
            "set-test-provider-enabled", self.provider, "true"
        )
        if _run(enabled, dry_run=self.dry_run).returncode != 0:
            raise RuntimeError(f"could not enable Android provider {self.provider}")

    def send(self, fix: LocationFix) -> bool:
        accuracy = fix.accuracy if fix.accuracy is not None else 25.0
        location = f"{fix.latitude:.8f},{fix.longitude:.8f}"
        command = self._location_command(
            "set-test-provider-location",
            self.provider,
            "--location",
            location,
            "--accuracy",
            f"{max(1.0, accuracy):.1f}",
            "--time",
            str(int(time.time() * 1000)),
        )
        return _run(command, dry_run=self.dry_run).returncode == 0

    def close(self) -> None:
        try:
            if self.created:
                _run(
                    self._location_command(
                        "set-test-provider-enabled", self.provider, "false"
                    ),
                    dry_run=self.dry_run,
                )
                _run(
                    self._location_command("remove-test-provider", self.provider),
                    dry_run=self.dry_run,
                )
        finally:
            if self._changed_mock_location_mode:
                _run(
                    self._appops_command(
                        "set", self._mock_location_mode or "default"
                    ),
                    dry_run=self.dry_run,
                )
                self._changed_mock_location_mode = False


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Bridge host GNSS fixes into a Waydroid mock provider."
    )
    parser.add_argument(
        "--source",
        choices=("mmcli", "gpspipe"),
        default="mmcli",
        help="live host source (default: mmcli)",
    )
    parser.add_argument("--modem", help="ModemManager modem number; auto-detected")
    parser.add_argument(
        "--input",
        type=Path,
        help="read NMEA/JSON lines from a file instead of a live source",
    )
    parser.add_argument(
        "--provider",
        default="fused",
        help="Android test provider name (default: fused)",
    )
    parser.add_argument(
        "--enable-gps",
        action="store_true",
        help="enable ModemManager GPS NMEA and request 1-second refreshes",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="actually change the modem/Waydroid state; otherwise dry-run",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="inject the first valid fix and exit",
    )
    parser.add_argument(
        "--min-interval",
        type=float,
        default=1.0,
        help="minimum seconds between injected fixes (default: 1)",
    )
    return parser


def run(arguments: argparse.Namespace) -> int:
    dry_run = not arguments.apply
    if arguments.min_interval < 0:
        raise ValueError("--min-interval cannot be negative")
    if arguments.enable_gps and arguments.source != "mmcli":
        raise ValueError("--enable-gps requires --source mmcli")
    if arguments.input is not None and not arguments.input.is_file():
        raise FileNotFoundError(arguments.input)

    provider = WaydroidProvider(arguments.provider, dry_run)
    last_injected = 0.0
    fixes = 0
    location_parser = ModemLocationParser()
    lines: TextIO | Iterator[str] | None = None
    try:
        provider.start()
        if arguments.input is not None:
            lines = input_lines(arguments.input)
        elif arguments.source == "mmcli":
            modem = arguments.modem or discover_modem()
            lines = _modem_lines(modem, arguments.enable_gps, dry_run)
        else:
            if not dry_run and shutil.which("gpspipe") is None:
                raise RuntimeError("gpspipe is not installed")
            lines = _gpsd_lines(dry_run)

        for line in lines:
            fix = location_parser.feed(line)
            if fix is None:
                continue
            now = time.monotonic()
            if not arguments.once and now - last_injected < arguments.min_interval:
                continue
            if not provider.send(fix):
                raise RuntimeError("Waydroid location injection failed")
            last_injected = now
            fixes += 1
            accuracy = "unknown" if fix.accuracy is None else f"{fix.accuracy:.1f}m"
            print(
                f"fix source={fix.source} lat={fix.latitude:.8f} "
                f"lon={fix.longitude:.8f} accuracy={accuracy} dry_run={dry_run}",
                flush=True,
            )
            if arguments.once:
                break
        if arguments.input is None and not arguments.once and not dry_run:
            raise RuntimeError("live location source ended unexpectedly")
    finally:
        if lines is not None and hasattr(lines, "close"):
            lines.close()  # type: ignore[union-attr]
        provider.close()
    if fixes == 0:
        raise RuntimeError("no valid location fix was received")
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    try:
        return run(arguments)
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        parser.error(str(error))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
