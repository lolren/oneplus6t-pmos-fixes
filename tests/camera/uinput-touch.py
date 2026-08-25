#!/usr/bin/env python3
"""Emit one bounded tap or pinch through a temporary uinput touchscreen.

This is an acceptance-test helper, not a background input service. It creates
one direct multi-touch device, emits exactly the requested gesture, destroys
the device in a finally block, and never reads or modifies a real input node.
Root is required only because postmarketOS protects /dev/uinput.
"""

from __future__ import annotations

import argparse
import fcntl
import os
import struct
import sys
import time
from dataclasses import dataclass


EV_SYN = 0x00
EV_KEY = 0x01
EV_ABS = 0x03
SYN_REPORT = 0

BTN_TOOL_FINGER = 0x145
BTN_TOUCH = 0x14A

ABS_X = 0x00
ABS_Y = 0x01
ABS_MT_SLOT = 0x2F
ABS_MT_TOUCH_MAJOR = 0x30
ABS_MT_POSITION_X = 0x35
ABS_MT_POSITION_Y = 0x36
ABS_MT_TRACKING_ID = 0x39
ABS_CNT = 0x40

INPUT_PROP_DIRECT = 0x01
BUS_VIRTUAL = 0x06
UINPUT_MAX_NAME_SIZE = 80

UINPUT_IOCTL_BASE = ord("U")
IOC_NRBITS = 8
IOC_TYPEBITS = 8
IOC_SIZEBITS = 14
IOC_NRSHIFT = 0
IOC_TYPESHIFT = IOC_NRSHIFT + IOC_NRBITS
IOC_SIZESHIFT = IOC_TYPESHIFT + IOC_TYPEBITS
IOC_DIRSHIFT = IOC_SIZESHIFT + IOC_SIZEBITS
IOC_NONE = 0
IOC_WRITE = 1


def ioctl_code(direction: int, number: int, size: int = 0) -> int:
    return (
        (direction << IOC_DIRSHIFT)
        | (UINPUT_IOCTL_BASE << IOC_TYPESHIFT)
        | (number << IOC_NRSHIFT)
        | (size << IOC_SIZESHIFT)
    )


UI_DEV_CREATE = ioctl_code(IOC_NONE, 1)
UI_DEV_DESTROY = ioctl_code(IOC_NONE, 2)
UI_SET_EVBIT = ioctl_code(IOC_WRITE, 100, struct.calcsize("i"))
UI_SET_KEYBIT = ioctl_code(IOC_WRITE, 101, struct.calcsize("i"))
UI_SET_ABSBIT = ioctl_code(IOC_WRITE, 103, struct.calcsize("i"))
UI_SET_PROPBIT = ioctl_code(IOC_WRITE, 110, struct.calcsize("i"))

INPUT_EVENT = struct.Struct("@llHHi")
UINPUT_USER_DEV = struct.Struct("<80sHHHHI" + "i" * (ABS_CNT * 4))


@dataclass(frozen=True)
class Point:
    x: int
    y: int


def unit_interval(value: str) -> float:
    parsed = float(value)
    if not 0.0 <= parsed <= 1.0:
        raise argparse.ArgumentTypeError("value must be between 0 and 1")
    return parsed


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be positive")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Emit one bounded tap or pinch from a temporary touchscreen."
    )
    parser.add_argument("--width", type=positive_int, default=1080)
    parser.add_argument("--height", type=positive_int, default=2340)
    parser.add_argument(
        "--settle-ms",
        type=positive_int,
        default=1200,
        help="wait for udev/compositor discovery (default: 1200)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print coordinates without using uinput"
    )
    subparsers = parser.add_subparsers(dest="gesture", required=True)

    tap = subparsers.add_parser("tap")
    tap.add_argument("--x", type=unit_interval, required=True)
    tap.add_argument("--y", type=unit_interval, required=True)
    tap.add_argument("--hold-ms", type=positive_int, default=80)

    pinch = subparsers.add_parser("pinch")
    pinch.add_argument("--center-x", type=unit_interval, default=0.5)
    pinch.add_argument("--center-y", type=unit_interval, default=0.5)
    pinch.add_argument("--start-span", type=unit_interval, default=0.18)
    pinch.add_argument("--end-span", type=unit_interval, default=0.55)
    pinch.add_argument("--duration-ms", type=positive_int, default=900)
    pinch.add_argument("--steps", type=positive_int, default=24)
    return parser.parse_args()


def to_point(x: float, y: float, width: int, height: int) -> Point:
    return Point(round(x * (width - 1)), round(y * (height - 1)))


def pinch_points(args: argparse.Namespace, span: float) -> tuple[Point, Point]:
    half_span = span / 2.0
    left = args.center_x - half_span
    right = args.center_x + half_span
    if left < 0.0 or right > 1.0:
        raise ValueError("pinch span exceeds the touchscreen bounds")
    return (
        to_point(left, args.center_y, args.width, args.height),
        to_point(right, args.center_y, args.width, args.height),
    )


def device_description(args: argparse.Namespace) -> bytes:
    name = b"Advanced Snapshot Test Touchscreen"
    name_field = name + bytes(UINPUT_MAX_NAME_SIZE - len(name))
    absmax = [0] * ABS_CNT
    absmin = [0] * ABS_CNT
    absfuzz = [0] * ABS_CNT
    absflat = [0] * ABS_CNT

    absmax[ABS_X] = args.width - 1
    absmax[ABS_Y] = args.height - 1
    absmax[ABS_MT_SLOT] = 1
    absmax[ABS_MT_TOUCH_MAJOR] = 255
    absmax[ABS_MT_POSITION_X] = args.width - 1
    absmax[ABS_MT_POSITION_Y] = args.height - 1
    absmax[ABS_MT_TRACKING_ID] = 65535

    return UINPUT_USER_DEV.pack(
        name_field,
        BUS_VIRTUAL,
        0x1D6B,
        0xA501,
        1,
        0,
        *absmax,
        *absmin,
        *absfuzz,
        *absflat,
    )


class Touchscreen:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        self.created = False
        self.closed = False

    def __enter__(self) -> "Touchscreen":
        try:
            for event_type in (EV_KEY, EV_ABS):
                fcntl.ioctl(self.fd, UI_SET_EVBIT, event_type)
            for key_code in (BTN_TOOL_FINGER, BTN_TOUCH):
                fcntl.ioctl(self.fd, UI_SET_KEYBIT, key_code)
            for axis in (
                ABS_X,
                ABS_Y,
                ABS_MT_SLOT,
                ABS_MT_TOUCH_MAJOR,
                ABS_MT_POSITION_X,
                ABS_MT_POSITION_Y,
                ABS_MT_TRACKING_ID,
            ):
                fcntl.ioctl(self.fd, UI_SET_ABSBIT, axis)
            fcntl.ioctl(self.fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT)
            os.write(self.fd, device_description(self.args))
            fcntl.ioctl(self.fd, UI_DEV_CREATE)
            self.created = True
            time.sleep(self.args.settle_ms / 1000.0)
            return self
        except BaseException:
            # __exit__ is not called when __enter__ fails or is interrupted.
            self.close()
            raise

    def __exit__(self, _type: object, _value: object, _traceback: object) -> None:
        self.close()

    def close(self) -> None:
        if self.closed:
            return
        try:
            if self.created:
                fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        finally:
            os.close(self.fd)
            self.closed = True

    def event(self, event_type: int, code: int, value: int) -> None:
        os.write(self.fd, INPUT_EVENT.pack(0, 0, event_type, code, value))

    def sync(self) -> None:
        self.event(EV_SYN, SYN_REPORT, 0)

    def set_slot(self, slot: int, tracking_id: int, point: Point) -> None:
        self.event(EV_ABS, ABS_MT_SLOT, slot)
        self.event(EV_ABS, ABS_MT_TRACKING_ID, tracking_id)
        self.event(EV_ABS, ABS_MT_POSITION_X, point.x)
        self.event(EV_ABS, ABS_MT_POSITION_Y, point.y)
        self.event(EV_ABS, ABS_MT_TOUCH_MAJOR, 40)

    def move_slot(self, slot: int, point: Point) -> None:
        self.event(EV_ABS, ABS_MT_SLOT, slot)
        self.event(EV_ABS, ABS_MT_POSITION_X, point.x)
        self.event(EV_ABS, ABS_MT_POSITION_Y, point.y)

    def begin(self, points: tuple[Point, ...]) -> None:
        for slot, point in enumerate(points):
            self.set_slot(slot, 100 + slot, point)
        self.event(EV_KEY, BTN_TOOL_FINGER, 1)
        self.event(EV_KEY, BTN_TOUCH, 1)
        self.event(EV_ABS, ABS_X, points[0].x)
        self.event(EV_ABS, ABS_Y, points[0].y)
        self.sync()

    def end(self, slots: int) -> None:
        for slot in range(slots):
            self.event(EV_ABS, ABS_MT_SLOT, slot)
            self.event(EV_ABS, ABS_MT_TRACKING_ID, -1)
        self.event(EV_KEY, BTN_TOUCH, 0)
        self.event(EV_KEY, BTN_TOOL_FINGER, 0)
        self.sync()


def print_plan(args: argparse.Namespace) -> None:
    if args.gesture == "tap":
        print(f"tap={to_point(args.x, args.y, args.width, args.height)}")
        return
    start = pinch_points(args, args.start_span)
    end = pinch_points(args, args.end_span)
    print(f"pinch_start={start[0]},{start[1]}")
    print(f"pinch_end={end[0]},{end[1]}")


def emit_gesture(args: argparse.Namespace) -> None:
    with Touchscreen(args) as touchscreen:
        if args.gesture == "tap":
            point = to_point(args.x, args.y, args.width, args.height)
            touchscreen.begin((point,))
            time.sleep(args.hold_ms / 1000.0)
            touchscreen.end(1)
            return

        start = pinch_points(args, args.start_span)
        end = pinch_points(args, args.end_span)
        touchscreen.begin(start)
        step_delay = args.duration_ms / args.steps / 1000.0
        for step in range(1, args.steps + 1):
            fraction = step / args.steps
            left = Point(
                round(start[0].x + (end[0].x - start[0].x) * fraction),
                round(start[0].y + (end[0].y - start[0].y) * fraction),
            )
            right = Point(
                round(start[1].x + (end[1].x - start[1].x) * fraction),
                round(start[1].y + (end[1].y - start[1].y) * fraction),
            )
            touchscreen.move_slot(0, left)
            touchscreen.move_slot(1, right)
            touchscreen.event(EV_ABS, ABS_X, left.x)
            touchscreen.event(EV_ABS, ABS_Y, left.y)
            touchscreen.sync()
            time.sleep(step_delay)
        touchscreen.end(2)


def main() -> int:
    args = parse_args()
    if args.gesture == "pinch":
        pinch_points(args, args.start_span)
        pinch_points(args, args.end_span)
        if args.steps > 120:
            raise ValueError("--steps must not exceed 120")
        if args.duration_ms > 5000:
            raise ValueError("--duration-ms must not exceed 5000")
    if args.dry_run:
        print_plan(args)
        return 0
    emit_gesture(args)
    print(f"gesture={args.gesture}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"uinput-touch: {error}", file=sys.stderr)
        raise SystemExit(1)
