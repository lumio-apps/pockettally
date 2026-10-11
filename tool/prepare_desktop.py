#!/usr/bin/env python3
"""Patches the generated windows/ or linux/ project in CI: window title and
Windows file details. Nothing has to be edited by hand.

Usage:
  python3 tool/prepare_desktop.py windows
  python3 tool/prepare_desktop.py linux

Fails loudly if the Flutter template changes and a patch no longer applies.
"""
import pathlib
import sys


def die(message: str) -> None:
    print(f"prepare_desktop.py: {message}", file=sys.stderr)
    sys.exit(1)


def replace(path: pathlib.Path, old: str, new: str, required: bool = True) -> bool:
    text = path.read_text(encoding="utf-8")
    if new in text and old not in text:
        return True
    if old not in text:
        if required:
            die(f"'{old}' not found in {path}")
        return False
    path.write_text(text.replace(old, new), encoding="utf-8")
    return True


def windows() -> None:
    main = pathlib.Path("windows/runner/main.cpp")
    replace(main, 'L"pockettally"', 'L"PocketTally"')
    rc = pathlib.Path("windows/runner/Runner.rc")
    replace(rc, 'VALUE "ProductName", "pockettally"',
            'VALUE "ProductName", "PocketTally"', required=False)
    replace(rc, 'VALUE "FileDescription", "pockettally"',
            'VALUE "FileDescription", "PocketTally"', required=False)
    replace(rc, 'VALUE "CompanyName", "com.lumio"',
            'VALUE "CompanyName", "Lumio Apps"', required=False)
    print("windows patched")


def linux() -> None:
    candidates = [pathlib.Path("linux/runner/my_application.cc"),
                  pathlib.Path("linux/my_application.cc")]
    app = next((p for p in candidates if p.exists()), None)
    if app is None:
        die("my_application.cc not found")
    replace(app, '"pockettally"', '"PocketTally"')
    print("linux patched")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("windows", "linux"):
        die("usage: prepare_desktop.py windows|linux")
    windows() if sys.argv[1] == "windows" else linux()
