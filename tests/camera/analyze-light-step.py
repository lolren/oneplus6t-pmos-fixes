#!/usr/bin/env python3
"""Summarize a bounded cam metadata log around an off/on/off light step."""

import argparse
import re
import statistics
from pathlib import Path


RE_LOG_START = re.compile(r"^\[(\d+):(\d+):(\d+(?:\.\d+)?)\]")
RE_FRAME = re.compile(r"^(\d+(?:\.\d+)?) .* seq: (\d+)")
RE_EXPOSURE = re.compile(r"ExposureTime = (\d+)")
RE_GAIN = re.compile(r"AnalogueGain = ([\d.]+)")


def log_seconds(match):
    return int(match.group(1)) * 3600 + int(match.group(2)) * 60 + float(
        match.group(3)
    )


def parse_markers(path):
    markers = []
    for line in path.read_text().splitlines():
        state, timestamp = line.split()
        markers.append((state, float(timestamp)))

    if [state for state, _ in markers] != ["off", "on", "off"]:
        raise ValueError(f"{path}: expected exactly: off, on, off")
    return markers


def parse_log(path):
    lines = path.read_text(errors="replace").splitlines()
    start_match = next(
        (RE_LOG_START.match(line) for line in lines if RE_LOG_START.match(line)),
        None,
    )
    if not start_match:
        raise ValueError(f"{path}: no libcamera start timestamp found")

    rows = []
    current = None
    for line in lines:
        match = RE_FRAME.match(line)
        if match:
            if current and {"time", "sequence", "exposure", "gain"} <= current.keys():
                rows.append(current)
            current = {"time": float(match.group(1)), "sequence": int(match.group(2))}
            continue

        if not current:
            continue

        match = RE_EXPOSURE.search(line)
        if match:
            current["exposure"] = int(match.group(1))
        match = RE_GAIN.search(line)
        if match:
            current["gain"] = float(match.group(1))

    if current and {"time", "sequence", "exposure", "gain"} <= current.keys():
        rows.append(current)
    if not rows:
        raise ValueError(f"{path}: no complete frame metadata found")

    return log_seconds(start_match), rows


def summarize(name, rows):
    if not rows:
        raise ValueError(f"no frames in {name} measurement window")

    exposure = statistics.median(row["exposure"] for row in rows)
    gain = statistics.median(row["gain"] for row in rows)
    product = statistics.median(row["exposure"] * row["gain"] for row in rows)
    print(
        f"{name:10s} frames={len(rows):3d} "
        f"seq={rows[0]['sequence']:03d}-{rows[-1]['sequence']:03d} "
        f"exposure={exposure:7.0f}us gain={gain:6.3f} "
        f"product={product:10.0f}"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("markers", type=Path)
    args = parser.parse_args()

    markers = parse_markers(args.markers)
    start, rows = parse_log(args.log)
    marker_start = markers[0][1]
    light_on = start + markers[1][1] - marker_start
    light_off = start + markers[2][1] - marker_start
    final_start = max(light_off + 1.0, rows[-1]["time"] - 1.0)

    summarize(
        "before",
        [row for row in rows if light_on - 1.0 <= row["time"] < light_on - 0.2],
    )
    summarize(
        "lit",
        [row for row in rows if light_off - 1.0 <= row["time"] < light_off - 0.2],
    )
    summarize("recovered", [row for row in rows if row["time"] >= final_start])


if __name__ == "__main__":
    main()
