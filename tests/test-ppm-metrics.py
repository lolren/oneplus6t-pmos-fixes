#!/usr/bin/env python3
"""Unit tests for the private-capture PPM regression metrics."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest


sys.dont_write_bytecode = True
SCRIPT = Path(__file__).parent / "camera" / "ppm-metrics.py"
SPEC = importlib.util.spec_from_file_location("ppm_metrics", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"could not load {SCRIPT}")
PPM_METRICS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PPM_METRICS)


def grayscale(values: list[int]) -> bytes:
    return bytes(channel for value in values for channel in (value, value, value))


class MetricsTests(unittest.TestCase):
    def test_flat_frame_has_no_detail_signal(self) -> None:
        result = PPM_METRICS.metrics(3, 3, grayscale([128] * 9), 250)
        self.assertEqual(result["edge"], 0)
        self.assertEqual(result["laplacian"], 0)

    def test_vertical_ramp_has_expected_detail_signals(self) -> None:
        pixels = grayscale([0, 128, 255] * 3)
        result = PPM_METRICS.metrics(3, 3, pixels, 250)
        self.assertAlmostEqual(result["edge"], 127.5)
        self.assertAlmostEqual(result["laplacian"], 1.0)

    def test_centre_impulse_has_laplacian_response(self) -> None:
        result = PPM_METRICS.metrics(
            3,
            3,
            grayscale([0, 0, 0, 0, 255, 0, 0, 0, 0]),
            250,
        )
        self.assertEqual(result["edge"], 0)
        self.assertEqual(result["laplacian"], 1020)

    def test_historical_colour_metrics_remain_unchanged(self) -> None:
        result = PPM_METRICS.metrics(1, 1, bytes((255, 0, 0)), 250)
        self.assertAlmostEqual(result["luma"], 0.2126 * 255)
        self.assertEqual(result["chroma"], 255)
        self.assertEqual(result["saturation"], 1)
        self.assertEqual(result["clipped"], 100)
        self.assertEqual(result["white"], 0)

    def test_green_ratio_uses_mean_of_red_and_blue(self) -> None:
        result = PPM_METRICS.metrics(
            2,
            1,
            bytes((64, 96, 48, 32, 48, 32)),
            250,
        )
        self.assertAlmostEqual(result["red_mean"], 48)
        self.assertAlmostEqual(result["green_mean"], 72)
        self.assertAlmostEqual(result["blue_mean"], 40)
        self.assertAlmostEqual(result["green_ratio"], 72 / 44)


if __name__ == "__main__":
    unittest.main()
