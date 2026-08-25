#!/usr/bin/env python3
"""Capture one private desktop screenshot through the XDG portal.

This helper is intended for unattended camera-UI acceptance checks on Phosh.
It keeps the portal request's D-Bus connection alive until the asynchronous
response arrives, then copies the returned file URI to a caller-owned path.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402


PORTAL_NAME = "org.freedesktop.portal.Desktop"
PORTAL_PATH = "/org/freedesktop/portal/desktop"
SCREENSHOT_INTERFACE = "org.freedesktop.portal.Screenshot"
REQUEST_INTERFACE = "org.freedesktop.portal.Request"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Capture a non-interactive screenshot through XDG Desktop Portal."
    )
    parser.add_argument("output", type=Path, help="private PNG output path")
    parser.add_argument(
        "--timeout",
        type=int,
        default=15,
        help="portal response timeout in seconds (default: 15)",
    )
    args = parser.parse_args()
    if not 1 <= args.timeout <= 60:
        parser.error("--timeout must be between 1 and 60 seconds")
    return args


def main() -> int:
    args = parse_args()
    output = args.output.expanduser().resolve()
    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)

    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = f"advanced_snapshot_{os.getpid()}"
    expected_path: str | None = None
    response: dict[str, object] = {}
    early_responses: list[tuple[str, int, dict[str, object]]] = []
    loop = GLib.MainLoop()

    def on_response(
        _connection: Gio.DBusConnection,
        _sender: str,
        object_path: str,
        _interface: str,
        _signal: str,
        parameters: GLib.Variant,
        _user_data: object,
    ) -> None:
        status, results = parameters.unpack()
        if expected_path is None:
            early_responses.append((object_path, status, results))
            return
        if object_path != expected_path:
            return
        response["status"] = status
        response["results"] = results
        response["path"] = object_path
        loop.quit()

    subscription = connection.signal_subscribe(
        PORTAL_NAME,
        REQUEST_INTERFACE,
        "Response",
        None,
        None,
        Gio.DBusSignalFlags.NONE,
        on_response,
        None,
    )

    options = {
        "handle_token": GLib.Variant("s", token),
        "interactive": GLib.Variant("b", False),
    }
    reply = connection.call_sync(
        PORTAL_NAME,
        PORTAL_PATH,
        SCREENSHOT_INTERFACE,
        "Screenshot",
        GLib.Variant("(sa{sv})", ("", options)),
        GLib.VariantType.new("(o)"),
        Gio.DBusCallFlags.NONE,
        args.timeout * 1000,
        None,
    )
    expected_path = reply.unpack()[0]

    for object_path, status, results in early_responses:
        if object_path == expected_path:
            response["status"] = status
            response["results"] = results
            response["path"] = object_path
            break

    def on_timeout() -> bool:
        response["timeout"] = True
        loop.quit()
        return GLib.SOURCE_REMOVE

    timeout_source = 0
    if "status" not in response:
        timeout_source = GLib.timeout_add_seconds(args.timeout, on_timeout)
        loop.run()
    if timeout_source and not response.get("timeout"):
        GLib.source_remove(timeout_source)
    connection.signal_unsubscribe(subscription)

    if response.get("timeout"):
        raise RuntimeError(f"portal did not answer within {args.timeout} seconds")
    if response.get("path") != expected_path:
        raise RuntimeError("portal response path did not match the request")
    if response.get("status") != 0:
        raise RuntimeError(f"portal rejected screenshot request: {response['status']}")

    results = response.get("results")
    if not isinstance(results, dict) or not isinstance(results.get("uri"), str):
        raise RuntimeError("portal response did not contain a screenshot URI")
    parsed_uri = urlparse(results["uri"])
    if parsed_uri.scheme != "file" or parsed_uri.netloc not in ("", "localhost"):
        raise RuntimeError("portal returned a non-local screenshot URI")

    source = Path(unquote(parsed_uri.path))
    if not source.is_file():
        raise RuntimeError("portal screenshot file does not exist")
    shutil.copyfile(source, output)
    output.chmod(0o600)
    print(output)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GLib.Error, OSError, RuntimeError) as error:
        print(f"capture-portal-screenshot: {error}", file=sys.stderr)
        raise SystemExit(1)
