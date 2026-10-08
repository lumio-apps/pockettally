# PocketTally

A simple, offline daily income and expense tracker for Android.
Part of the Lumio Apps family. No account, no ads, no tracking.

## Features (v0.1.0)

- Add income (daily, weekly or monthly) and daily expenses
- Income and expenses in one list, each entry separate (income green, expense red)
- Monthly balance, income and expense summary on the home screen
- Edit entries, swipe to delete with Undo
- One app-wide currency (INR, USD, EUR and many more), changeable in Settings
- Light, dark or system theme
- In-app "Check for updates" that downloads new releases from GitHub

Coming next: categories management, stats and charts, search and filter,
monthly budget, recurring entries, CSV backup and restore.

## Privacy

All data stays on your phone in a local database.
The `INTERNET` permission is used only when you tap "Check for updates",
which contacts the GitHub Releases page of this project.

## Build

```
flutter pub get
flutter run
```

Android project setup and release signing: see [SETUP_ANDROID.md](SETUP_ANDROID.md).

F-Droid build without the updater:

```
flutter build apk --dart-define=UPDATER=false
```

## License

GPL-3.0. Add the license text as `LICENSE` in the repo root.
