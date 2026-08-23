#!/usr/bin/env python3
"""Query or set a V4L2 absolute-focus control without v4l2-ctl.

The default operation is read-only.  A write requires an explicit --set and is
validated against the control range reported by the kernel driver.
"""

from __future__ import annotations

import argparse
import fcntl
import os
import struct
import sys
import time


V4L2_CTRL_CLASS_CAMERA = 0x009A0000
V4L2_CID_CAMERA_CLASS_BASE = V4L2_CTRL_CLASS_CAMERA | 0x900
V4L2_CID_FOCUS_ABSOLUTE = V4L2_CID_CAMERA_CLASS_BASE + 10

V4L2_CTRL_FLAG_DISABLED = 0x0001
V4L2_CTRL_TYPE_INTEGER = 1

IOC_WRITE = 1
IOC_READ = 2
IOC_READWRITE = IOC_READ | IOC_WRITE

QUERY_CONTROL_FORMAT = "=II32siiiiIII"
CONTROL_FORMAT = "=Ii"


def ioctl_code(direction: int, number: int, size: int) -> int:
    """Build an asm-generic Linux ioctl request for type 'V'."""

    return (direction << 30) | (size << 16) | (ord("V") << 8) | number


VIDIOC_QUERYCTRL = ioctl_code(
    IOC_READWRITE, 36, struct.calcsize(QUERY_CONTROL_FORMAT)
)
VIDIOC_G_CTRL = ioctl_code(IOC_READWRITE, 27, struct.calcsize(CONTROL_FORMAT))
VIDIOC_S_CTRL = ioctl_code(IOC_READWRITE, 28, struct.calcsize(CONTROL_FORMAT))


def query_focus(fd: int) -> dict[str, int | str]:
    payload = bytearray(
        struct.pack(
            QUERY_CONTROL_FORMAT,
            V4L2_CID_FOCUS_ABSOLUTE,
            0,
            b"",
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        )
    )
    fcntl.ioctl(fd, VIDIOC_QUERYCTRL, payload, True)
    (
        control_id,
        control_type,
        name,
        minimum,
        maximum,
        step,
        default,
        flags,
        _reserved0,
        _reserved1,
    ) = struct.unpack(QUERY_CONTROL_FORMAT, payload)

    if flags & V4L2_CTRL_FLAG_DISABLED:
        raise RuntimeError("the absolute-focus control is disabled")
    if control_type != V4L2_CTRL_TYPE_INTEGER:
        raise RuntimeError(f"unexpected focus control type {control_type}")

    return {
        "id": control_id,
        "name": name.split(b"\0", 1)[0].decode("utf-8", "replace"),
        "minimum": minimum,
        "maximum": maximum,
        "step": step,
        "default": default,
        "flags": flags,
    }


def get_focus(fd: int) -> int:
    payload = bytearray(struct.pack(CONTROL_FORMAT, V4L2_CID_FOCUS_ABSOLUTE, 0))
    fcntl.ioctl(fd, VIDIOC_G_CTRL, payload, True)
    _control_id, value = struct.unpack(CONTROL_FORMAT, payload)
    return value


def set_focus(fd: int, value: int) -> int:
    payload = bytearray(
        struct.pack(CONTROL_FORMAT, V4L2_CID_FOCUS_ABSOLUTE, value)
    )
    fcntl.ioctl(fd, VIDIOC_S_CTRL, payload, True)
    _control_id, applied = struct.unpack(CONTROL_FORMAT, payload)
    return applied


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", help="lens V4L2 subdevice, such as /dev/v4l-subdev21")
    parser.add_argument(
        "--set",
        dest="position",
        type=int,
        metavar="POSITION",
        help="set an explicit absolute-focus position",
    )
    parser.add_argument(
        "--hold",
        type=float,
        default=0.0,
        metavar="SECONDS",
        help="keep the actuator powered after --set while another process captures",
    )
    parser.add_argument(
        "--settle-ms",
        type=int,
        default=50,
        metavar="MILLISECONDS",
        help="settling delay after --set (default: 50)",
    )
    args = parser.parse_args()

    if args.hold < 0:
        parser.error("--hold must not be negative")
    if args.settle_ms < 0:
        parser.error("--settle-ms must not be negative")
    if args.position is None and args.hold:
        parser.error("--hold requires --set")

    return args


def main() -> int:
    args = parse_args()
    open_flags = os.O_RDWR | getattr(os, "O_CLOEXEC", 0)

    try:
        with open(args.device, "rb+", buffering=0, opener=lambda path, _: os.open(path, open_flags)) as device:
            info = query_focus(device.fileno())
            print(f"device={args.device}")
            print(f"control={info['name']}")
            print(
                "range="
                f"{info['minimum']}..{info['maximum']} "
                f"step={info['step']} default={info['default']}"
            )

            if args.position is None:
                print(f"position={get_focus(device.fileno())}")
                return 0

            minimum = int(info["minimum"])
            maximum = int(info["maximum"])
            step = int(info["step"])
            if not minimum <= args.position <= maximum:
                raise ValueError(
                    f"position {args.position} is outside {minimum}..{maximum}"
                )
            if step > 1 and (args.position - minimum) % step:
                raise ValueError(f"position {args.position} is not aligned to step {step}")

            before = get_focus(device.fileno())
            applied = set_focus(device.fileno(), args.position)
            if args.settle_ms:
                time.sleep(args.settle_ms / 1000)
            after = get_focus(device.fileno())
            print(f"position_before={before}")
            print(f"position_requested={args.position}")
            print(f"position_applied={applied}")
            print(f"position_after={after}")

            if args.hold:
                print(f"holding_seconds={args.hold:g}", flush=True)
                time.sleep(args.hold)

    except (OSError, RuntimeError, ValueError) as error:
        print(f"{os.path.basename(sys.argv[0])}: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
