#!/usr/bin/env python3
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main()
