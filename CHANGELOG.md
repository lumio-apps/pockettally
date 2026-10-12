# Changelog

## 0.9.4

- New bottom bar on phones: Home, Lend/Borrow and Insights. The + button moved to the bottom-right corner
- Settings are now on your profile page: tap your photo or name on Home. Budgets open from there or from the budget line on Home
- New + button menu: tap + to add an expense, income, lend/borrow entry or savings goal (with a short animation; tap outside or Back to close). On a computer the Add button opens the same choices
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
