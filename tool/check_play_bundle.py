#!/usr/bin/env python3
"""Checks the Google Play app bundle before it is uploaded.

Usage:
  python3 tool/check_play_bundle.py app-release.aab [build-folder]
  python3 tool/check_play_bundle.py --self-test

1. 16 KB pages: Google Play does not accept apps whose 64-bit native
   libraries (arm64-v8a, x86_64) are built for 4 KB pages. Every LOAD
   segment of every such library must be aligned to 16384 bytes.
2. Permissions: the merged manifest in the build folder must not contain
   permissions that Google Play restricts and that this app does not use.
   All permissions found are printed, so the build log shows them.
"""
import pathlib
import re
import struct
import sys
import tempfile
import zipfile

PAGE = 16384
PT_LOAD = 1

# Not used by the Play build. INTERNET and REQUEST_INSTALL_PACKAGES belong to
# the GitHub updater; exact alarms are only for alarm clock and calendar apps.
FORBIDDEN = {
    "android.permission.INTERNET",
    "android.permission.REQUEST_INSTALL_PACKAGES",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.USE_EXACT_ALARM",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_MEDIA_AUDIO",
    "android.permission.QUERY_ALL_PACKAGES",
}

LIB = re.compile(r"^[^/]+/lib/(arm64-v8a|x86_64)/[^/]+\.so$")


def load_alignments(data):
    """The p_align of every LOAD segment of a 64-bit little-endian ELF file,
    or None when the file is not one."""
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        return None
    phoff = struct.unpack_from("<Q", data, 0x20)[0]
    phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    result = []
    for i in range(phnum):
        off = phoff + i * phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type == PT_LOAD:
            result.append(struct.unpack_from("<Q", data, off + 48)[0])
    return result


def check_libraries(aab):
    bad = []
    count = 0
    with zipfile.ZipFile(aab) as z:
        for name in sorted(z.namelist()):
            if not LIB.match(name):
                continue
            aligns = load_alignments(z.read(name))
            if aligns is None:
                continue
            count += 1
            if any(a < PAGE for a in aligns):
                bad.append(name)
    print(f"16 KB check: {count} native libraries looked at")
    for name in bad:
        print(f"  NOT aligned to 16 KB: {name}")
    return not bad


def find_manifest(build):
    found = [
        p for p in pathlib.Path(build).rglob("AndroidManifest.xml")
        if "merged_manifest" in str(p).lower() and "release" in str(p).lower()
    ]
    return max(found, key=lambda p: p.stat().st_mtime) if found else None


def permissions(text):
    return sorted(set(re.findall(
        r'<uses-permission[^>]*?android:name="([^"]+)"', text)))


def check_permissions(build):
    manifest = find_manifest(build)
    if manifest is None:
        print("Permission check: merged manifest not found, skipped")
        return True
    found = permissions(manifest.read_text(encoding="utf-8", errors="replace"))
    print(f"Permissions in {manifest}:")
    for p in found:
        print(f"  {p}")
    bad = [p for p in found if p in FORBIDDEN]
    for p in bad:
        print(f"  NOT allowed in the Play build: {p}")
    return not bad


def elf(align):
    """A minimal 64-bit ELF header with one LOAD segment."""
    head = bytearray(64)
    head[:4] = b"\x7fELF"
    head[4], head[5], head[6] = 2, 1, 1
    struct.pack_into("<Q", head, 0x20, 64)       # e_phoff
    struct.pack_into("<HH", head, 0x36, 56, 1)   # e_phentsize, e_phnum
    ph = bytearray(56)
    struct.pack_into("<I", ph, 0, PT_LOAD)
    struct.pack_into("<Q", ph, 48, align)
    return bytes(head + ph)


def self_test():
    assert load_alignments(elf(0x4000)) == [0x4000]
    assert load_alignments(elf(0x1000)) == [0x1000]
    assert load_alignments(b"not an elf file at all" * 10) is None
    with tempfile.TemporaryDirectory() as tmp:
        good = pathlib.Path(tmp) / "good.aab"
        with zipfile.ZipFile(good, "w") as z:
            z.writestr("base/lib/arm64-v8a/libgood.so", elf(0x4000))
            z.writestr("base/lib/armeabi-v7a/lib32.so", elf(0x1000))  # 32-bit: ignored
        assert check_libraries(good)
        bad = pathlib.Path(tmp) / "bad.aab"
        with zipfile.ZipFile(bad, "w") as z:
            z.writestr("base/lib/x86_64/libold.so", elf(0x1000))
        assert not check_libraries(bad)
        m = pathlib.Path(tmp) / "build/intermediates/merged_manifest/release/AndroidManifest.xml"
        m.parent.mkdir(parents=True)
        m.write_text('<manifest><uses-permission android:name="android.permission.VIBRATE"/></manifest>')
        assert check_permissions(pathlib.Path(tmp) / "build")
        m.write_text('<manifest><uses-permission android:name="android.permission.INTERNET"/></manifest>')
        assert not check_permissions(pathlib.Path(tmp) / "build")
    print("self-test ok")


def main():
    args = sys.argv[1:]
    if args == ["--self-test"]:
        self_test()
        return 0
    if not args or len(args) > 2:
        print(__doc__)
        return 2
    ok = check_libraries(args[0])
    ok = check_permissions(args[1] if len(args) == 2 else "build") and ok
    print("OK" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
