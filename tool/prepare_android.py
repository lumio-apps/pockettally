#!/usr/bin/env python3
"""Patches the generated android/ project in CI, so nothing has to be edited by hand.

Usage:
  python3 tool/prepare_android.py manifest   # permissions, app label, reminder setup
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
    # Daily reminder: plan the reminders again after the phone restarts.
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
)

# flutter_local_notifications: receivers for scheduled notifications.
REMINDER_RECEIVERS = (
    '        <receiver android:exported="false"\n'
    '            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>\n'
    '        <receiver android:exported="false"\n'
    '            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
    '            <intent-filter>\n'
    '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
    '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
    '                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n'
    '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
    '            </intent-filter>\n'
    '        </receiver>\n'
)

# Small white icon for the reminder in the status bar (two arrows).
NOTIFY_ICON = """<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M16,17.01V10h-2v7.01h-3L15,21l4,-3.99h-3zM9,3L5,6.99h3V14h2V6.99h3L9,3z"/>
</vector>
"""

# The icon is only named from Dart code, so tell the resource shrinker to
# keep it.
KEEP_RESOURCES = """<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_notify" />
"""

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
    # The home screen widget (install_widget_files, WIDGET_RECEIVER,
    # WIDGET_LAUNCH_FILTER) is switched off since 0.9.2: it made the app
    # crash on start. Kept here to bring it back later.
    text = MANIFEST.read_text()
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
    if "ScheduledNotificationReceiver" not in text:
        if "</application>" not in text:
            die("no </application> tag in AndroidManifest.xml")
        text = text.replace(
            "</application>", REMINDER_RECEIVERS + "    </application>", 1)
    MANIFEST.write_text(text)
    install_reminder_files()
    patch_gradle_for_notifications()
    print("manifest patched")


def install_reminder_files() -> None:
    res = pathlib.Path("android/app/src/main/res")
    (res / "drawable").mkdir(parents=True, exist_ok=True)
    (res / "drawable" / "ic_stat_notify.xml").write_text(NOTIFY_ICON)
    (res / "raw").mkdir(parents=True, exist_ok=True)
    (res / "raw" / "keep.xml").write_text(KEEP_RESOURCES)


def patch_gradle_for_notifications() -> None:
    """flutter_local_notifications needs core library desugaring, Java 17,
    Android 7.0 (API 24) or newer and compile SDK 36."""
    text = GRADLE.read_text()
    if "isCoreLibraryDesugaringEnabled" in text:
        print("gradle already patched")
        return
    if "compileOptions {" not in text:
        die("no compileOptions block in build.gradle.kts")
    text = text.replace(
        "compileOptions {",
        "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
        1,
    )
    for old in ("VERSION_1_8", "VERSION_11"):
        text = text.replace(f"JavaVersion.{old}", "JavaVersion.VERSION_17")
    for old in ("JVM_1_8", "JVM_11"):
        text = text.replace(f"JvmTarget.{old}", "JvmTarget.JVM_17")
    if "minSdk = flutter.minSdkVersion" not in text:
        die("minSdk line not found in build.gradle.kts")
    text = text.replace(
        "minSdk = flutter.minSdkVersion",
        "minSdk = maxOf(flutter.minSdkVersion, 24)",
        1,
    )
    if "compileSdk = flutter.compileSdkVersion" not in text:
        die("compileSdk line not found in build.gradle.kts")
    text = text.replace(
        "compileSdk = flutter.compileSdkVersion",
        "compileSdk = maxOf(flutter.compileSdkVersion, 36)",
        1,
    )
    text += (
        "\ndependencies {\n"
        '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
        "}\n"
    )
    GRADLE.write_text(text)
    print("gradle patched for notifications")


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
