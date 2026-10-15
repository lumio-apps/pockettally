# Google Play listing: answers for Play Console

Everything to copy into Play Console. The text below is the listing in English.
Check each answer against what the Console asks on that day, because Google
changes the forms from time to time.

## Store listing

| Field | Value |
|---|---|
| App name | PocketTally |
| Default language | English (United States) |
| App or game | App |
| Free or paid | Free |
| Category | Finance |
| Tags | Budgeting, Expense tracker, Personal finance |
| Website | https://github.com/lumio-apps/pockettally |
| Privacy policy | https://github.com/lumio-apps/pockettally/blob/HEAD/PRIVACY.md |
| Contact email | Shown publicly on the store page. Use an address you are happy to publish. |

### Short description (80 characters at most)

```
Simple offline income and expense tracker. No ads, no account, no internet.
```

### Full description (4000 characters at most)

```
PocketTally is a simple income and expense tracker that keeps everything on your phone. No account, no ads, no tracking, and no internet connection: the app does not even ask for the internet permission.

EVERYDAY MONEY TRACKING
• Add income and expenses in a few taps, with categories, notes and tags
• Daily, weekly and monthly views with clear totals and balance
• Budgets with warnings when a category is close to its limit
• Lend and Borrow: remember who owes you and whom you owe, with reminders
• Savings goals
• Attach a photo of a bill to an entry

REPORTS
• Reports by category and month by month
• PDF report: choose the period, the categories and the sections
• Export and import your entries as CSV

YOUR DATA STAYS YOURS
• Everything is stored only on your device
• Backup to a file and restore it any time, also on a new phone
• App lock with a PIN (stored only as a salted hash)

MADE TO FIT YOU
• 20 languages, including 10 Indian languages
• 27 currencies
• Light and dark theme, six accent colors
• Home screen widgets and long-press shortcuts to add an entry fast
• Daily reminder at the time you choose

PocketTally is free and open source (GPL-3.0). There is no premium version and no locked features. Source code: github.com/lumio-apps/pockettally
```

### Graphics

| Asset | File |
|---|---|
| App icon 512 x 512 | `fastlane/metadata/android/en-US/images/icon.png` |
| Feature graphic 1024 x 500 | `fastlane/metadata/android/en-US/images/featureGraphic.png` |
| Phone screenshots 1080 x 1920 (upload all 6, in this order) | `docs/play-store/phone-1.png` to `phone-6.png` |

### What's new (500 characters at most)

```
First release on Google Play. Track income and expenses offline, with budgets, Lend & Borrow, savings goals, PDF reports, backups, PIN lock and 20 languages.
```

## App content

| Form | Answer |
|---|---|
| Privacy policy | The URL above |
| Ads | No, the app has no ads |
| App access | All functionality is available without special access (the PIN lock is optional and set by the user) |
| Target audience | 18 and over. Not designed for children |
| Content rating | Questionnaire category "Utility, productivity, communication or other". Answer No to every question about violence, sexual content, language, drugs, gambling and user-generated content that is shared with others |
| Data safety | "Does your app collect or share any of the required user data types?" No. The app has no internet permission and sends nothing anywhere. Nothing else to fill in |
| Advertising ID | No |
| Government app | No |
| Financial features | "My app doesn't provide any financial features". It only lets people note their own income and expenses; it moves no money, gives no loans and offers no banking or trading. Read the options again in the Console and pick the one that says no financial features |
| Health apps, news apps, COVID-19 | Not applicable |
| Account deletion | Not applicable: there are no accounts |

## Permissions

The Play build has no internet, no exact alarms and no install-packages
permission, and the build fails if the all-files or photo-and-video
permissions (`MANAGE_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`,
`READ_MEDIA_VIDEO`) ever get in. So no permission declaration form should be
needed. If the Console still asks for one, check the permission list printed
by the "Check the bundle for Google Play" step of the GitHub Actions run.

Reminders in the Play build come as close to the chosen time as Android
allows (Android can delay them a little to save battery). The GitHub and
F-Droid builds can ask for "Alarms & reminders" and then ring on the minute.

## Release steps

1. Push the version tag (for example `v1.3.3`). The GitHub Actions run builds
   `pockettally-v1.3.3-play.aab`. Open the run, check that the job **play** is
   green, and download the file from **Artifacts**.
2. Play Console, create the app. Leave **Play App Signing** switched on.
   The key you sign with on GitHub becomes the upload key; Google keeps the
   real app signing key.
3. **Testing, Closed testing**: create a track, add at least 12 testers (their
   Google accounts, by email list or a Google Group), upload the `.aab`, and send
   the opt-in link. The testers must stay opted in for 14 days in a row.
4. When the 14 days are over, press **Apply for production** on the Dashboard,
   answer the questions, and wait for the review (usually up to 7 days).
5. Each later upload needs a higher version code. The build number in
   `pubspec.yaml` (the number after the `+`) is used for it, so always raise
   it before a tag.
