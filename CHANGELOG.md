# Changelog

## 1.6.0 (Trash)

- Deleted entries now go to a **Trash** (Settings › Backup) and stay there for 30 days. Tap one to put it back or to delete it for good, or use the button at the top to empty the Trash
- The Undo button after a delete still works
- Entries in the Trash are not counted in balances, reports or search, and are not saved in backups or CSV files
- After 30 days they are removed automatically when the app starts
- Old data and old backups are not changed; one column is added to the database on open
- All 20 languages

## 1.5.0 (fingerprint and face unlock)

- New switch in Settings › Security: **Unlock with fingerprint or face** (shown when the app lock is on and the phone has a fingerprint or face set up). PocketTally asks the phone's own prompt when it opens; the PIN pad stays under it as the fallback
- Turning it on asks for your fingerprint or face once, to be sure it works
- Turning the app lock off also turns this off
- All 20 languages

## 1.4.1 (Reduce effects)

- New switch in Settings › Appearance: **Reduce effects**. Flat panels with a thin edge instead of soft shadows, no pressed-card movement, no sliding tab pill and only a plain fade between pages. It can feel smoother on older phones
- It also switches on by itself when Android's "remove animations" is on
- All 20 languages

## 1.4.0 (neumorphic look)

- New look: soft neumorphism. Cards, buttons and the bottom bar look pushed out of one calm surface, and progress bars, the balance icon and the selected tab look pressed into it. It follows your accent color and works in light and dark mode
- Smooth motion: cards sink in when you press them, the selected tab is a pill that slides to the new tab, the + button turns, and the + menu fades in over the page
- The old frosted glass look and its blur are gone
- No change in how the app works

## 1.3.11 (start-up crash fix)

- Fixed "PocketTally could not start" (NoSuchMethodError in shared_preferences) in the release APK: the release build no longer shrinks the code with R8, which removed methods that the plugins call by name
- The APK is a little bigger

## 1.3.10 (GitHub only, update check is back)

- **Settings › Check for updates** is back (Android only). It asks GitHub for the newest release, downloads the APK and opens the installer. It runs only when you tap it, and sends none of your data
- The app has the internet and "install apps" permissions again, for this button only
- PocketTally is released on GitHub only. The Google Play and F-Droid files (store texts, recipe, app bundle build) are removed from the project
- Privacy Policy and README updated

## 1.3.8 (README and screenshots)

- New README with screenshots of the glass look, and a new banner
- New store screenshots and feature graphic for Google Play and F-Droid
- No change in how the app works

## 1.3.7 (no update check)

- The "Check for updates" button and the code behind it are gone. The app never goes online now, in every version (Google Play, F-Droid and GitHub): no internet permission and no permission to install apps
- Update through the store you installed from, or install a newer APK from the GitHub releases page over the old one; your data stays
- Fewer libraries in the app (no HTTP and no file opener)
- Privacy Policy updated

## 1.3.6 (Android only)

- PocketTally is now an Android-only app. The Windows installer and the Linux AppImage are no longer built, and their code is gone: the desktop database (FFI), the desktop update and the file-dialog photo picker
- The APK is smaller and has fewer libraries (no bundled desktop SQLite)
- Phones and tablets are not affected. Windows and Linux files from older releases stay on the release pages but get no more updates
- README, banner and store graphic now say Android only

## 1.3.5 (glass look)

- New glass look for the whole app: pages sit on a soft gradient in the colors of your accent color, cards are frosted and translucent with a light edge, in both light and dark mode
- The bottom bar floats as a glass bar with the + button in the middle; the + menu blurs the page behind it
- Home: the balance card, income and expense tiles and the quick actions are glass
- Pages change with a short fade and a small slide up

## 1.3.4 (store permissions)

- The Google Play and F-Droid builds no longer carry storage, photo, video and audio permissions that a plugin had added. The app never used them: pictures come from the system photo picker and files from the system file dialog
- The Play bundle check also refuses these permissions

## 1.3.3 (Google Play)

- A build for Google Play: no update check, no internet permission, no permission to install apps and no exact alarms. Reminders in this build come as close to the chosen time as Android allows
- The app now targets Android 16 (API 36), as Google Play asks since 31 August 2026
- The release build also makes a signed app bundle (`.aab`) for Google Play. Before it can be uploaded, it is checked for 16 KB memory pages and for permissions Google Play does not allow
- Privacy Policy (`PRIVACY.md`), the Google Play listing texts and 6 screenshots in `docs/play-store/`

## 1.3.2 (safety)

- Backups with bill photos are written photo by photo, to a temporary file that is renamed when it is complete. A big photo collection no longer needs several times its size in memory, and a stopped phone never leaves a half-written backup
- The automatic backup starts 8 seconds after the app opens, so starting the app is never slowed down by it
- CSV import: a row with an amount like "NaN", "Infinity" or an absurdly big number is skipped; before, it stopped the whole import
- Amounts above 1,000,000,000,000 are not accepted (typing mistakes; thousands of them could overflow the totals)
- Home screen widgets: an error in one widget can no longer crash the app

## 1.3.1 (F-Droid)

- The app is ready for F-Droid: a build without the update check, without the internet permission and without the permission to install apps
- Store listing (title, descriptions, icon, screenshots) added in `fastlane/`
- New signing key for the GitHub release APK. **Android will not update an app installed with the old key.** Before you install this version: open the old app, make a backup in Settings, uninstall it, install this version and restore the backup

## 1.3.0 (7 Indian languages)

- New languages: Gujarati (ગુજરાતી), Tamil (தமிழ்), Telugu (తెలుగు), Marathi (मराठी), Kannada (ಕನ್ನಡ), Malayalam (മലയാളം) and Punjabi (ਪੰਜਾਬੀ). The app now has 20 languages
- Choose one on the welcome screen or in Settings › Language. A phone set to one of these languages starts the app in it
- Everything is translated: the app, the built-in categories, notifications and the PDF report. On Android the widget names and the app-icon shortcuts follow the phone's language
- Dates and month names follow the chosen language

## 1.2.0 (PDF report)

- The PDF button on Reports opens a page to choose what goes into the PDF: the period (this or last month, this or last year, or any dates), all entries or only expenses or income, all categories or chosen ones, and the sections (summary, by category, budgets, month by month, all entries with notes and tags)
- Yearly report: for a year (or any period longer than a month) the PDF shows every month with income, expenses and balance, and the total
- The PDF is now in the app's language for all 13 languages. Hindi, Bangla, Arabic, Urdu, Chinese and Japanese text (also names you typed yourself) is drawn with the phone's own fonts, so no big fonts were added to the app
- Arabic and Urdu reports read right to left
- New look for the PDF in the app's blue, with the logo
- The app remembers your choices for next time
- Reminders (daily and Lend & Borrow) now come at the exact minute and ring: the app asks once for Android's "Alarms & reminders" permission (before, Android could hold a reminder back for up to an hour)
- Settings › Reminder: "Send a test notification", "Allow on-time reminders", and a shortcut to the app's phone settings for phones that stop apps in the background

## 1.1.0 (widgets and shortcuts, Android)

- Home screen widgets in the app's blue: a big one (this month's balance, income, expenses, and "− Expense" / "+ Income" buttons) and a small one (balance and − / +)
- Tap the balance to open the app; tap − or + to go straight to the expense or income form
- The widgets follow "Hide balance" and update after every change
- Long-press the app icon for "Add expense" and "Add income"
- Made without any extra plugin (the widget of 0.9.2 used one and was removed because it crashed)

## 1.0.0 (new look, part 2)

- Lend & Borrow reminders (Android): "Remind me" on a record, with a day and time. A notification says who owes you, or whom you owe, and how much is still open. Change or remove it from the record's menu; it stops when the record is settled
- People from earlier records can be picked with one tap
- Split bill: when adding an expense, tap "Split bill" and add the people. Split equally or with your own amounts, paid by you or by someone else. Your share is saved as the expense; what others owe you (or what you owe) goes to Lend & Borrow
- New Reports: week, month or year; net savings with the change from the period before; income and expenses with their change in percent; a donut and a bar per category; income vs expenses for the last 6 weeks or months, or month by month
- New Settings: a profile card at the top (opens your profile), a privacy box, and settings in groups with colored icons
- The photo on Home opens your profile
- Safety: a new column for reminders is only added to the database; nothing is rewritten

## 0.9.11 (new icon)

- New app icon in the app's blue
- Android 13 and newer: with "Themed icons" on in the phone settings, the icon turns light in light mode and dark in dark mode
- The opening screen is light or dark with the phone's dark mode
- The logo inside the app (lock screen, welcome screen, sidebar) is light or dark with the app's theme
- Windows and Linux use the new rounded blue icon

## 0.9.10 (new look, part 1)

- New look in blue (the other colors are still in Settings › Accent color)
- New bottom bar: Home, Entries, + , Reports, Settings
- Home: balance card with an eye button to hide amounts, income and expense tiles, a spending overview donut with the budget, quick actions, and "See all"
- Entries tab: search, All / Income / Expense chips, month by month, more filters (category, dates, amounts)
- Entries now have a time (new entries get the current time; older ones show no time)
- Categories have icons: chosen in the category editor, or picked from the name
- Add entry: quick categories (the ones you use most) and a reminder that data stays on the device
- Smooth animations: sections fade in, the balance counts up, the donut draws itself
- Safety: the database is only extended (never rewritten), and an untouched copy from before this update is kept on the device

## 0.9.9

- Auto backup (Profile › Data): a backup file every week or every day, made when you open the app. On Android it goes to Documents/PocketTally, which stays even if the app is removed (older phones: the app's folder on the phone storage). The last 5 are kept
- Backups can include bill photos ("Include bill photos"); restore brings them back
- Duplicate an entry: long-press it, or open it and tap the copy button. The copy is dated today
- Budgets: "Carry over what's left" adds last month's unused monthly budget to this month
- Bill photos of deleted entries (or replaced photos) are removed from the phone

## 0.9.8

- App lock: turn it on in your profile (Security) and choose a 4-digit PIN. The app asks for it when it opens and after it was in the background (immediately, after 1 or 5 minutes). After 5 wrong PINs you wait 30 seconds. Forgot the PIN? The app can be reset (all data is deleted; restore a backup afterwards). The PIN is stored only as a salted hash
- Daily reminder (Android): a notification at the time you choose, only on days you haven't added anything yet
- Android 7.0 or newer is now needed (the reminder needs it)

## 0.9.7

- CSV import: a category written in other letter case ("food") now goes to the existing category ("Food") instead of making a separate one
- Search stays fast with thousands of results
- Lend/Borrow on Home now opens the Lend/Borrow tab
- The welcome screen now says these choices can be changed later in your profile

## 0.9.6

- The + button no longer covers the amount of the last entry on Home and Insights
- Home shows the 50 newest entries, so it stays fast with years of data. "See all entries" below them opens the full list (Search)

## 0.9.5

- New bottom bar on phones: Home, Lend/Borrow and Insights. The + button moved to the bottom-right corner
- Settings are now on your profile page: tap your photo or name on Home. Budgets open from there or from the budget line on Home
- Lend & Borrow in the + menu now opens the form for a new entry directly

## 0.9.4

- New + button menu: tap + to add an expense, income, lend/borrow or savings goal (with a short animation; tap outside or Back to close). On a computer the Add button opens the same choices
- Category is now one field like Note and Tags: tap it to pick from a list (with search when there are many, and Manage at the bottom)
- A new entry starts with the category you used last time
- Releases now have one file per system: `…-android.apk`, `…-windows-setup.exe` and `…-linux-x86_64.AppImage`. The Android APK installs over every earlier one, also the processor-specific ones

## 0.9.3

- Profile: tap your name or picture on Home to add a profile photo (camera or gallery) and change your name, currency and number format
- Settings now holds only app settings, in three groups: Appearance, Data and About. Your profile is at the top
- The profile photo is included in backups
- Fix: renaming or deleting a category now also updates recurring entries and favorites
- Fix: recurring entries could be added twice when the app was opened and resumed at the same moment

## 0.9.2

- Fix: "PocketTally keeps stopping" on Android since 0.8.0. The home screen widget and the app-icon shortcuts are removed for now; they caused the crash and will come back once fixed. Your data is unchanged

## 0.9.1

- Fix: the app could stay on the start screen after updating to 0.8.0. Database updates now check what is missing and finish an update that stopped half way
- If the app ever cannot start, it shows the reason with a Copy button instead of hanging; your data is not touched
- The widget, launcher shortcuts and recurring entries can no longer stop the app from opening

## 0.9.0

- Highlights on Insights (month view): spending compared with last month, the top category, which category went up, average per day and how much of your income you kept
- Calendar: see every day of a month with its spending, tap a day for its entries or to add one on that date (Home > calendar button)
- Upcoming bills on Home: recurring entries due in the next 7 days
- Recurring entries show what they cost (and bring in) per month
- CSV export and import (Settings): open your entries in Excel or Google Sheets, or add entries from a spreadsheet

## 0.8.1

- The amount is now typed with the device's own keyboard (the app's number keypad is gone); Enter or Done saves
- Fix: budget warnings and the restore message could show their numbers in the wrong places

## 0.8.0

- Recurring entries: choose Repeat (every day, week, month or year) when adding an entry, e.g. salary or rent. Due entries are added automatically when you open the app; pause or stop them in Settings > Recurring entries
- Favorites: tap the star in the entry form to save it; favorites appear on Home and add an entry with one tap (long-press to remove)
- Tags: label entries like #trip or #office; search finds them
- Android: long-press the app icon for "Add expense" and "Add income" (removed again in 0.9.2)
- Android: home screen widget with this month's balance and a + button (removed again in 0.9.2)
- Backups include recurring entries, favorites and tags

## 0.7.0

- PocketTally for Windows and Linux (same features and data format as on phones)
- Windows: installer (per user, no admin rights) and a portable zip
- Linux: AppImage (one file, updates itself) and a tar.gz
- Wide windows get a sidebar with every page: Home, Insights, Budgets, Savings goals, Lend & Borrow, Categories and Settings
- Quick add panel next to Home on large screens
- Keyboard: Ctrl+N new entry, Ctrl+F search, type amounts with the number keys, Enter to save
- "Check for updates" on desktop downloads the new installer or AppImage and restarts the app
- Move your data between phone and computer with Back up / Restore
- Fix: PDF report test failed when month names were not loaded yet

## 0.6.5

- 13 languages: English, Hindi, Armenian, Chinese, Spanish, Arabic, French, Bengali, Portuguese, Russian, Urdu, Indonesian and Japanese
- Arabic and Urdu are shown right to left
- New welcome screen in three steps: language, name and currency (suggested from your region)
- Change the language any time in Settings > Language
- Built-in categories (Food, Salary…) are shown in your language; your own categories stay as you typed them
- Dates and month names follow the app language
- PDF reports are in your language for English, Spanish, French, Portuguese, Indonesian, Russian and Armenian, and in English for the other languages

## 0.6.0

- Number format setting: 1,234.56 · 1.234,56 · 1 234,56 · 1'234.56 · 12,34,567.89 (Automatic picks one from your currency)
- Decimals setting: currencies like JPY and KRW are shown without decimals; you can turn decimals on or off for any currency
- The keypad uses your decimal separator (or a 00 key when decimals are off)
- Categories: drag to reorder, and hide the ones you don't use (old entries keep them)
- Accent color: Forest, Ocean, Plum, Wine or Graphite
- Smaller downloads: releases now include one APK per processor type, and the in-app updater picks the right one for your phone
- Backups include the new settings and category order (older versions can still read them)

## 0.5.0

- New logo ("Pocket In/Out") and splash screen
- New look: bottom navigation (Home, Insights, Budgets, Settings) with a big + button
- New Home: balance card, budget bar, quick actions and grouped recent entries
- New Add entry screen with its own calculator keypad and category chips
- Insights: last 6 months bar chart in the month view
- Lend & Borrow: track money you lent or borrowed, part payments and what is still open
- Savings goals: set a target, add or take out money, see progress
- Bill photos: attach a photo of the receipt to any entry (camera or gallery)
- Backups now include lend/borrow records and savings goals (bill photos are not included)

## 0.4.0

- Stats: new Year view with a month-by-month bar chart of income and expenses
- Year view lists every month; tap one to open it
- Save any day, week, month or year as a PDF report (Stats > PDF button)
- Delete button on the edit screen, and long-press an entry for Edit / Delete

## 0.3.0

- Monthly budget with progress bar and a warning when it is exceeded
- Monthly limit for each expense category, with warnings
- New Budgets screen (Settings > Budgets, or tap the budget bar on Home)
- Calculator in the amount field: type 120+45 or use the + − × ÷ buttons
- Choose whether weeks start on Monday or Sunday
- Armenian Dram (AMD ֏) added
- Back up all data to a file and restore it on any phone

## 0.2.0

- New app icon and splash screen
- Categories: create your own, rename, recolor or delete (entries move to "Other")
- Stats screen: day, week and month totals with a pie chart by category
- Search and filter by text, type, category, date range and amount
- Category colors shown in the entry list
- GPL-3.0 license added

## 0.1.0

- First release: add income and expenses, monthly summary, edit and delete
  with Undo, app-wide currency, dark mode, in-app update check
