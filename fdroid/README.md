# F-Droid

F-Droid builds the app from source and signs it with its own key, so the
F-Droid and GitHub builds cannot update each other. Someone moving between
them has to make a backup in the app, uninstall, install the other build and
restore.

## What is different in the F-Droid build

- The app has no update check (F-Droid updates the app itself).
- `python3 tool/prepare_android.py manifest --fdroid` removes the
  `INTERNET` and `REQUEST_INSTALL_PACKAGES` permissions if a plugin adds them.
  The app never goes online.
- No Google services and no tracking libraries are used.

## Store listing

`fastlane/metadata/android/en-US/` holds the title, the short and full
description, the icon, the feature graphic, the screenshots and one changelog
per version. **Every release needs a new `changelogs/<versionCode>.txt`**
(the number after the `+` in `pubspec.yaml`, 500 bytes at most).

## Submitting the app

1. Push the tag (for example `v1.3.1`) so the code and the metadata are public.
2. Fork https://gitlab.com/fdroid/fdroiddata.
3. Copy `fdroid/com.lumio.pockettally.yml` to
   `metadata/com.lumio.pockettally.yml` in the fork.
4. Open a merge request and answer the reviewers.
