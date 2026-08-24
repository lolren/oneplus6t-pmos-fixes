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
        raise ValueError(f"{path}: expected {expected} pixel bytes, got {len(pixels)}")

    return width, height, pixels


def metrics(width, height, pixels, threshold):
    count = len(pixels) // 3
    luma = 0.0
    chroma = 0.0
    saturation = 0.0
    clipped = 0
    white = 0
    luma_plane = bytearray(count)

    for index, offset in enumerate(range(0, len(pixels), 3)):
        red, green, blue = pixels[offset : offset + 3]
        high = max(red, green, blue)
        low = min(red, green, blue)
        spread = high - low
        pixel_luma = (54 * red + 183 * green + 19 * blue) >> 8

        # Preserve the historical luma metric for comparisons with older runs.
        luma += 0.2126 * red + 0.7152 * green + 0.0722 * blue
        luma_plane[index] = pixel_luma
        chroma += spread
        saturation += spread / high if high else 0.0
        clipped += high >= threshold
        white += low >= threshold

    edge = 0
    laplacian = 0
    detail_count = max((width - 2) * (height - 2), 1)
    for y in range(1, height - 1):
        row = y * width
        for x in range(1, width - 1):
            index = row + x
            center = luma_plane[index]
            left = luma_plane[index - 1]
            right = luma_plane[index + 1]
            above = luma_plane[index - width]
            below = luma_plane[index + width]
            edge += abs(right - left) + abs(below - above)
            laplacian += abs(4 * center - left - right - above - below)

    return {
        "luma": luma / count,
        "chroma": chroma / count,
        "saturation": saturation / count,
        "clipped": 100.0 * clipped / count,
        "white": 100.0 * white / count,
        # Scene-dependent regression signals: compare only like-for-like frames.
        "edge": edge / (2.0 * detail_count),
        "laplacian": laplacian / detail_count,
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
        result = metrics(width, height, pixels, args.threshold)
        print(
            f"{path}: {width}x{height} "
            f"luma={result['luma']:.1f} "
            f"chroma={result['chroma']:.1f} "
            f"saturation={result['saturation']:.3f} "
            f"near_clip={result['clipped']:.2f}% "
            f"near_white={result['white']:.2f}% "
            f"edge={result['edge']:.2f} "
            f"laplacian={result['laplacian']:.2f}"
        )


if __name__ == "__main__":
    main()
