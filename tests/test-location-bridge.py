#!/usr/bin/env python3
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "waydroid-location-bridge.py"
SPEC = importlib.util.spec_from_file_location("waydroid_location_bridge", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def nmea(payload):
    checksum = 0
    for character in payload:
        checksum ^= ord(character)
    return f"${payload}*{checksum:02X}"


class LocationBridgeTests(unittest.TestCase):
    def test_gga_coordinates_and_accuracy(self):
        fix = MODULE.parse_location_line(
            nmea(
                "GPGGA,123519,5012.579,N,00214.012,W,1,08,0.9,100.0,M,0.0,M,,"
            )
        )
        self.assertIsNotNone(fix)
        assert fix is not None
        self.assertAlmostEqual(fix.latitude, 50.20965, places=5)
        self.assertAlmostEqual(fix.longitude, -2.233533, places=5)
        self.assertAlmostEqual(fix.accuracy, 4.5, places=2)
        self.assertEqual(fix.source, "nmea-gga")

    def test_invalid_or_unfixed_nmea_is_ignored(self):
        sentence = nmea("GPGGA,123519,5012.579,N,00214.012,W,0,00,,100.0,M,0.0,M,,")
        self.assertIsNone(MODULE.parse_location_line(sentence))
        self.assertIsNone(MODULE.parse_location_line(sentence[:-2] + "00"))

    def test_gpsd_tpv(self):
        fix = MODULE.parse_location_line(
            json.dumps(
                {
                    "class": "TPV",
                    "mode": 3,
                    "lat": 51.747,
                    "lon": -2.218,
                    "alt": 70.0,
                    "epx": 4.0,
                    "epy": 6.0,
                }
            )
        )
        self.assertIsNotNone(fix)
        assert fix is not None
        self.assertEqual(fix.latitude, 51.747)
        self.assertEqual(fix.longitude, -2.218)
        self.assertEqual(fix.accuracy, 6.0)
        self.assertEqual(fix.source, "gpsd-tpv")

    def test_modemmanager_formatted_decimal_record(self):
        parser = MODULE.ModemLocationParser()
        self.assertIsNone(parser.feed("GPS location | supported: yes"))
        self.assertIsNone(parser.feed("             | longitude: -2.218000"))
        fix = parser.feed(
            "             | latitude: 51.747000 | altitude: 70.0 "
            "| horizontal accuracy: 6.0"
        )
        self.assertIsNotNone(fix)
        assert fix is not None
        self.assertAlmostEqual(fix.latitude, 51.747, places=6)
        self.assertAlmostEqual(fix.longitude, -2.218, places=6)
        self.assertEqual(fix.accuracy, 6.0)
        self.assertEqual(fix.altitude, 70.0)
        self.assertEqual(fix.source, "modemmanager-gps")

    def test_modemmanager_repeated_coordinate_does_not_mix_records(self):
        parser = MODULE.ModemLocationParser()
        self.assertIsNone(parser.feed("GPS location | latitude: 51.747"))
        self.assertIsNone(parser.feed("GPS location | latitude: 51.748"))
        fix = parser.feed("             | longitude: -2.219")
        self.assertIsNotNone(fix)
        assert fix is not None
        self.assertEqual(fix.latitude, 51.748)
        self.assertEqual(fix.longitude, -2.219)

    def test_modemmanager_out_of_range_coordinates_are_ignored(self):
        parser = MODULE.ModemLocationParser()
        self.assertIsNone(parser.feed("GPS | latitude: 190.0"))
        self.assertIsNone(parser.feed("GPS | longitude: -2.218"))

    def test_modemmanager_poll_requires_advancing_gps_utc(self):
        first = "modem.location.gps.utc : 123519.00\n"
        second = "modem.location.gps.utc : 123520.00\n"
        responses = [
            subprocess.CompletedProcess([], 0, first, ""),
            subprocess.CompletedProcess([], 0, first, ""),
            subprocess.CompletedProcess([], 0, second, ""),
        ]
        with mock.patch.object(MODULE.subprocess, "run", side_effect=responses) as run:
            with mock.patch.object(MODULE.time, "sleep"):
                lines = MODULE._modem_lines("7", False, False)
                self.assertEqual(next(lines), second)
                lines.close()
        self.assertEqual(run.call_count, 3)
        self.assertEqual(
            run.call_args.args[0],
            ["mmcli", "-m", "7", "--location-get", "--output-keyvalue"],
        )

    def test_modemmanager_poll_prefers_gga_accuracy_record(self):
        output = "".join(
            [
                "modem.location.gps.nmea.value[1] : '$GPRMC,123519,A'\n",
                "modem.location.gps.nmea.value[2] : '$GPGGA,123519,fix'\n",
            ]
        )
        ordered = MODULE._ordered_modem_lines(output)
        self.assertIn("$GPGGA", ordered[0])
        self.assertIn("$GPRMC", ordered[1])

    def test_modemmanager_temporary_gps_state_is_restored(self):
        status = "".join(
            [
                "modem.location.enabled : 3gpp-lac-ci\n",
                "modem.location.gps.refresh-rate : 3600\n",
            ]
        )
        commands = []

        def command_result(command, *, dry_run, timeout=10.0):
            commands.append(command)
            output = status if "--location-status" in command else ""
            return subprocess.CompletedProcess(command, 0, output, "")

        first = "modem.location.gps.utc : 123519.00\n"
        second = "modem.location.gps.utc : 123520.00\n"
        polls = [
            subprocess.CompletedProcess([], 0, first, ""),
            subprocess.CompletedProcess([], 0, second, ""),
        ]
        with mock.patch.object(MODULE, "_run", side_effect=command_result):
            with mock.patch.object(MODULE.subprocess, "run", side_effect=polls):
                with mock.patch.object(MODULE.time, "sleep"):
                    lines = MODULE._modem_lines("7", True, False)
                    self.assertEqual(next(lines), second)
                    lines.close()

        self.assertEqual(
            commands,
            [
                ["mmcli", "-m", "7", "--location-status", "--output-keyvalue"],
                [
                    "mmcli",
                    "-m",
                    "7",
                    "--location-enable-gps-raw",
                    "--location-enable-gps-nmea",
                ],
                ["mmcli", "-m", "7", "--location-set-gps-refresh-rate=1"],
                ["mmcli", "-m", "7", "--location-set-gps-refresh-rate=3600"],
                [
                    "mmcli",
                    "-m",
                    "7",
                    "--location-disable-gps-raw",
                    "--location-disable-gps-nmea",
                ],
            ],
        )

    def test_modemmanager_restores_only_sources_enabled_by_bridge(self):
        status = "".join(
            [
                "modem.location.enabled : 3gpp-lac-ci, gps-nmea\n",
                "modem.location.gps.refresh-rate : 1\n",
            ]
        )
        commands = []

        def command_result(command, *, dry_run, timeout=10.0):
            commands.append(command)
            output = status if "--location-status" in command else ""
            return subprocess.CompletedProcess(command, 0, output, "")

        first = "modem.location.gps.utc : 123519.00\n"
        second = "modem.location.gps.utc : 123520.00\n"
        polls = [
            subprocess.CompletedProcess([], 0, first, ""),
            subprocess.CompletedProcess([], 0, second, ""),
        ]
        with mock.patch.object(MODULE, "_run", side_effect=command_result):
            with mock.patch.object(MODULE.subprocess, "run", side_effect=polls):
                with mock.patch.object(MODULE.time, "sleep"):
                    lines = MODULE._modem_lines("7", True, False)
                    self.assertEqual(next(lines), second)
                    lines.close()

        self.assertEqual(
            commands,
            [
                ["mmcli", "-m", "7", "--location-status", "--output-keyvalue"],
                ["mmcli", "-m", "7", "--location-enable-gps-raw"],
                ["mmcli", "-m", "7", "--location-disable-gps-raw"],
            ],
        )

    def test_modemmanager_missing_state_fails_before_gps_mutation(self):
        result = subprocess.CompletedProcess(
            [], 0, "modem.location.enabled : --\n", ""
        )
        with mock.patch.object(MODULE, "_run", return_value=result) as run:
            lines = MODULE._modem_lines("7", True, False)
            with self.assertRaisesRegex(RuntimeError, "restorable GPS state"):
                next(lines)
        self.assertEqual(run.call_count, 1)
        self.assertIn("--location-status", run.call_args.args[0])

    def test_android_default_appop_mode_is_accepted(self):
        provider = MODULE.WaydroidProvider("fused", False)
        result = subprocess.CompletedProcess(
            [], 0, "No operations.\nDefault mode: deny\n", ""
        )
        with mock.patch.object(MODULE, "_run", return_value=result):
            self.assertEqual(provider._read_mock_location_mode(), "deny")

    def test_live_fix_log_omits_coordinates(self):
        fix = MODULE.LocationFix(10.123456, 20.654321, 6.0, source="nmea-gga")
        live = MODULE._fix_log_message(fix, False)
        self.assertIn("source=nmea-gga", live)
        self.assertIn("injected=true", live)
        self.assertNotIn("10.123456", live)
        self.assertNotIn("20.654321", live)
        dry_run = MODULE._fix_log_message(fix, True)
        self.assertIn("10.12345600,20.65432100", dry_run.replace(" lon=", ","))

    def test_android_status_zero_exception_is_failure(self):
        result = subprocess.CompletedProcess(
            [],
            0,
            "Exception occurred while executing providers:\n"
            "java.lang.SecurityException: MOCK_LOCATION denied\n",
            "",
        )
        self.assertFalse(MODULE._android_command_succeeded(result))

    def test_dry_run_injects_first_fix_without_waydroid(self):
        sentence = nmea("GPRMC,123519,A,5012.579,N,00214.012,W,0.0,0.0,230826,,,A")
        with tempfile.TemporaryDirectory(prefix="location-bridge-test-") as directory:
            input_path = Path(directory) / "nmea.log"
            input_path.write_text(sentence + "\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--input", str(input_path), "--once"],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("set-test-provider-location fused", result.stdout)
        self.assertIn("50.20965000,-2.23353333", result.stdout)
        self.assertIn("dry_run=True", result.stdout)
        self.assertIn(
            "waydroid shell -- cmd appops get 0 android:mock_location",
            result.stdout,
        )
        self.assertIn(
            "waydroid shell -- cmd appops set --uid 0 android:mock_location allow",
            result.stdout,
        )
        self.assertIn(
            "waydroid shell -- cmd appops set --uid 0 android:mock_location default",
            result.stdout,
        )
        self.assertIn(" --time ", result.stdout)
        self.assertNotIn("waydroid shell cmd", result.stdout)
        self.assertNotIn("--supportsAltitude", result.stdout)
        self.assertNotIn("--supportsSpeed", result.stdout)
        self.assertNotIn("--supportsBearing", result.stdout)

    def test_dry_run_injects_formatted_modemmanager_fix(self):
        formatted = "\n".join(
            [
                "GPS location | longitude: -2.218000",
                "             | latitude: 51.747000",
            ]
        )
        with tempfile.TemporaryDirectory(prefix="location-bridge-test-") as directory:
            input_path = Path(directory) / "mmcli.log"
            input_path.write_text(formatted + "\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--input", str(input_path), "--once"],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("set-test-provider-location fused", result.stdout)
        self.assertIn("51.74700000,-2.21800000", result.stdout)
        self.assertIn("source=modemmanager-gps", result.stdout)


if __name__ == "__main__":
    unittest.main()
