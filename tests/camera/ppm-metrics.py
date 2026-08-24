#!/usr/bin/env python3
"""Report simple colour and clipping metrics for binary PPM captures."""

import argparse
from pathlib import Path


def read_token(stream):
    while True:
        byte = stream.read(1)
        if not byte:
            raise ValueError("unexpected end of PPM header")
        if byte == b"#":
            stream.readline()
        elif not byte.isspace():
            break

    token = bytearray(byte)
    while True:
        byte = stream.read(1)
        if not byte or byte.isspace():
            return bytes(token)
        token.extend(byte)


def read_ppm(path):
    with path.open("rb") as stream:
        magic = read_token(stream)
        width = int(read_token(stream))
        height = int(read_token(stream))
        maximum = int(read_token(stream))
        pixels = stream.read()

    if magic != b"P6":
        raise ValueError(f"{path}: expected a binary P6 PPM")
    if maximum != 255:
        raise ValueError(f"{path}: expected an 8-bit PPM, got max {maximum}")

    expected = width * height * 3
    if len(pixels) != expected:
        raise ValueError(
            f"{path}: expected {expected} pixel bytes, got {len(pixels)}"
        )

    return width, height, pixels


def metrics(pixels, threshold):
    count = len(pixels) // 3
    luma = 0.0
    chroma = 0.0
    saturation = 0.0
    clipped = 0
    white = 0

    for offset in range(0, len(pixels), 3):
        red, green, blue = pixels[offset : offset + 3]
        high = max(red, green, blue)
        low = min(red, green, blue)
        spread = high - low

        luma += 0.2126 * red + 0.7152 * green + 0.0722 * blue
        chroma += spread
        saturation += spread / high if high else 0.0
        clipped += high >= threshold
        white += low >= threshold

    return {
        "luma": luma / count,
        "chroma": chroma / count,
        "saturation": saturation / count,
        "clipped": 100.0 * clipped / count,
        "white": 100.0 * white / count,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--threshold",
        type=int,
        default=250,
        choices=range(1, 256),
        metavar="1..255",
        help="near-clipping channel threshold (default: 250)",
    )
    parser.add_argument("images", nargs="+", type=Path)
    args = parser.parse_args()

    for path in args.images:
        width, height, pixels = read_ppm(path)
        result = metrics(pixels, args.threshold)
        print(
            f"{path}: {width}x{height} "
            f"luma={result['luma']:.1f} "
            f"chroma={result['chroma']:.1f} "
            f"saturation={result['saturation']:.3f} "
            f"near_clip={result['clipped']:.2f}% "
            f"near_white={result['white']:.2f}%"
        )


if __name__ == "__main__":
    main()
