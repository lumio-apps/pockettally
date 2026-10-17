#!/usr/bin/env python3
"""Patches the generated android/ project in CI, so nothing has to be edited by hand.

Usage:
  python3 tool/prepare_android.py manifest   # permissions (internet and install for the
                                             # update check, no storage permissions), app label,
                                             # reminder, widgets, shortcuts
  python3 tool/prepare_android.py signing    # release signing from key.properties

Fails loudly if the Flutter template changes and a patch no longer applies.
"""
import pathlib
import shutil
import sys

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")
GRADLE = pathlib.Path("android/app/build.gradle.kts")

# For "Check for updates" in Settings: it asks GitHub for the newest release
# (INTERNET), downloads the APK and opens the installer
# (REQUEST_INSTALL_PACKAGES). Nothing happens in the background.
UPDATER_PERMISSIONS = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n'
)

# Remove storage and photo/video permissions if a plugin adds them. The app does
# not need them: pictures come from the system photo picker and files from the
# system file dialog. Google Play restricts them.
NO_STORAGE_PERMISSIONS = (
    '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" tools:node="remove"/>\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove"/>\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove"/>\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" tools:node="remove"/>\n'
)

# Daily reminder: plan the reminders again after the phone restarts.
BOOT_PERMISSION = (
    '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
)

# Reminders at the exact minute (Android 12+ asks the user first).
EXACT_ALARM_PERMISSION = (
    '    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>\n'
)

TOOLS_NS = 'xmlns:tools="http://schemas.android.com/tools"'

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


# Home screen widgets (big and small). See tool/android/kotlin.
WIDGET_RECEIVERS = (
    '        <receiver android:name=".BalanceWidgetProvider"\n'
    '            android:exported="false"\n'
    '            android:label="@string/widget_big_name">\n'
    '            <intent-filter>\n'
    '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
    '            </intent-filter>\n'
    '            <meta-data android:name="android.appwidget.provider"\n'
    '                android:resource="@xml/balance_widget_info"/>\n'
    '        </receiver>\n'
    '        <receiver android:name=".BalanceWidgetSmallProvider"\n'
    '            android:exported="false"\n'
    '            android:label="@string/widget_small_name">\n'
    '            <intent-filter>\n'
    '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
    '            </intent-filter>\n'
    '            <meta-data android:name="android.appwidget.provider"\n'
    '                android:resource="@xml/balance_widget_small_info"/>\n'
    '        </receiver>\n'
)

# Long-press shortcuts ("Add expense", "Add income"), inside MainActivity.
SHORTCUTS_META = (
    '            <meta-data android:name="android.app.shortcuts"\n'
    '                android:resource="@xml/shortcuts"/>\n'
)


def install_android_extras() -> None:
    """Copies the widgets, shortcuts and MainActivity (with the channel the
    app uses for them) from tool/android into the generated project."""
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
    if "package com.lumio.pockettally" not in main_activity.read_text():
        die("unexpected package in MainActivity.kt")
    for name in ("MainActivity.kt", "WidgetProviders.kt"):
        shutil.copyfile(src / "kotlin" / name, main_activity.parent / name)


def patch_manifest() -> None:
    """Permissions, label, reminders, widgets and shortcuts."""
    # Since 1.1.0 the widgets work without the home_widget plugin (which
    # made 0.9.2 crash on start): plain Android code reads texts the app
    # saves in its settings.
    text = MANIFEST.read_text()
    if "RECEIVE_BOOT_COMPLETED" not in text:
        if "<application" not in text:
            die("no <application> tag in AndroidManifest.xml")
        extra = (UPDATER_PERMISSIONS + NO_STORAGE_PERMISSIONS
                 + BOOT_PERMISSION + EXACT_ALARM_PERMISSION)
        text = text.replace("<application", extra + "    <application", 1)
    if TOOLS_NS not in text:
        if "<manifest " not in text:
            die("no <manifest> tag in AndroidManifest.xml")
        text = text.replace("<manifest ", "<manifest " + TOOLS_NS + " ", 1)
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
    if "BalanceWidgetProvider" not in text:
        text = text.replace(
            "</application>", WIDGET_RECEIVERS + "    </application>", 1)
    if "android.app.shortcuts" not in text:
        if text.count("</activity>") != 1:
            die("expected exactly one <activity> in AndroidManifest.xml")
        text = text.replace("</activity>", SHORTCUTS_META + "        </activity>", 1)
    MANIFEST.write_text(text)
    install_reminder_files()
    install_android_extras()
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
    # Google Play: new apps and updates must target Android 16 (API 36) or
    # newer since 31 August 2026. Flutter's own default may be lower.
    if "targetSdk = flutter.targetSdkVersion" in text:
        text = text.replace(
            "targetSdk = flutter.targetSdkVersion",
            "targetSdk = maxOf(flutter.targetSdkVersion, 36)",
            1,
        )
    else:
        print("warning: targetSdk line not found; Google Play needs API 36")
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
    args = sys.argv[1:]
    if args == ["manifest"]:
        patch_manifest()
    elif args == ["signing"]:
        patch_signing()
    else:
        die("usage: prepare_android.py manifest | signing")
