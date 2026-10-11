#!/usr/bin/env python3
"""Patches the generated android/ project in CI, so nothing has to be edited by hand.

Usage:
  python3 tool/prepare_android.py manifest   # permissions, app label, widget
  python3 tool/prepare_android.py signing    # release signing from key.properties

Fails loudly if the Flutter template changes and a patch no longer applies.
"""
import pathlib
import shutil
import sys

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")
GRADLE = pathlib.Path("android/app/build.gradle.kts")

PERMISSIONS = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n'
)

GRADLE_HEADER = """import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""

SIGNING_BLOCK = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

"""


def die(message: str) -> None:
    print(f"prepare_android.py: {message}", file=sys.stderr)
    sys.exit(1)


WIDGET_RECEIVER = (
    '        <receiver android:name=".BalanceWidgetProvider" android:exported="true">\n'
    '            <intent-filter>\n'
    '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
    '            </intent-filter>\n'
    '            <meta-data android:name="android.appwidget.provider"\n'
    '                android:resource="@xml/balance_widget_info"/>\n'
    '        </receiver>\n'
)

WIDGET_LAUNCH_FILTER = (
    '            <intent-filter>\n'
    '                <action android:name="es.antonborri.home_widget.action.LAUNCH"/>\n'
    '            </intent-filter>\n'
)


def install_widget_files() -> None:
    """Copies the home screen widget (Kotlin + resources) from tool/android."""
    src = pathlib.Path("tool/android")
    res = pathlib.Path("android/app/src/main/res")
    for f in (src / "res").rglob("*"):
        if f.is_file():
            target = res / f.relative_to(src / "res")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, target)
    main_activity = next(
        pathlib.Path("android/app/src/main").rglob("MainActivity.kt"), None)
    if main_activity is None:
        die("MainActivity.kt not found")
    shutil.copyfile(src / "kotlin" / "BalanceWidgetProvider.kt",
                    main_activity.parent / "BalanceWidgetProvider.kt")
    if "package com.lumio.pockettally" not in main_activity.read_text():
        die("unexpected package in MainActivity.kt")


def patch_manifest() -> None:
    install_widget_files()
    text = MANIFEST.read_text()
    if "BalanceWidgetProvider" not in text:
        if "</application>" not in text:
            die("no </application> in AndroidManifest.xml")
        text = text.replace("</application>", WIDGET_RECEIVER + "    </application>", 1)
    if "home_widget.action.LAUNCH" not in text:
        if "</activity>" not in text:
            die("no </activity> in AndroidManifest.xml")
        text = text.replace("</activity>", WIDGET_LAUNCH_FILTER + "        </activity>", 1)
    if "REQUEST_INSTALL_PACKAGES" not in text:
        if "<application" not in text:
            die("no <application> tag in AndroidManifest.xml")
        text = text.replace("<application", PERMISSIONS + "    <application", 1)
    if 'android:label="pockettally"' in text:
        text = text.replace(
            'android:label="pockettally"', 'android:label="PocketTally"', 1
        )
    if "PocketTally" not in text:
        die("could not set the app label")
    MANIFEST.write_text(text)
    print("manifest patched")


def patch_signing() -> None:
    text = GRADLE.read_text()
    if "keystoreProperties" in text:
        print("signing already patched")
        return
    if "buildTypes {" not in text:
        die("no buildTypes block in build.gradle.kts")
    old_line = 'signingConfig = signingConfigs.getByName("debug")'
    if old_line not in text:
        die("release signingConfig line not found in build.gradle.kts")
    text = text.replace("buildTypes {", SIGNING_BLOCK + "    buildTypes {", 1)
    text = text.replace(
        old_line, 'signingConfig = signingConfigs.getByName("release")', 1
    )
    GRADLE.write_text(GRADLE_HEADER + text)
    print("signing patched")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("manifest", "signing"):
        die("usage: prepare_android.py manifest|signing")
    patch_manifest() if sys.argv[1] == "manifest" else patch_signing()
