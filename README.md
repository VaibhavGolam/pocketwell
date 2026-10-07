# Pocketwell

A simple expense tracker for Android and iOS, built with Flutter. It shows how much came in this month, how much went out, and where it went. It also keeps track of money you lent or borrowed (udhaar), savings goals, and a short money tip each day.

Everything is manual and offline. All data stays on the phone.

## What is new in 1.1

- **Budgets**: set a monthly limit per category. A bar fills as you spend, turns amber at 80% and red at 100%. Saving an entry that pushes a category past 80% or past its limit shows a warning. Home shows the budgets for the month on screen. Settings, Budgets lists every category.
- **Repeating entries**: rent, salary, subscriptions, EMIs. Weekly, monthly or yearly. They are added when you open the app on or after the due date, dated on the day they were due, and marked with a small repeat icon. You can start one from the **Repeat** row on the Add screen, or manage them in Settings, Repeating entries. A rule set for the 31st uses the last day in shorter months.
- **Backup and restore**: Settings, Your data. Back up shares a `.json` file (to Drive, WhatsApp, Files). Restore reads one and replaces everything in the app, after asking. If the file is wrong, nothing is changed.
- **CSV export**: entries and udhaar, for Excel or Google Sheets.
- **App lock**: a 4 digit PIN, plus fingerprint or face where the phone has it. Locks at launch and after the app has been away for a time you choose. If you forget the PIN, the lock screen has a button that uses the phone's own screen lock.
- **Search**: the magnifier on Home. Search notes and categories, and filter by type, category, date and amount.

The app lock keeps people out of the app. It does not encrypt the database file on the phone.

## What is in version 1

- **Home**: money in, money out, what is left, a donut of spending by category, a day by day bar chart, and a line comparing with last month. Tap a category to see its entries. Use the arrows to look at past months.
- **Add entry**: type an amount, tap an emoji category, save. Income uses the same screen. You can add your own categories.
- **People**: one running balance per person, with two totals at the top ("You will get" and "You will pay"). Partial payments just reduce the balance. Each person can have a due date, which sets a reminder at 9:00 that morning. A button opens WhatsApp with a polite message and the amount filled in.
- **Goals**: a savings goal with a target, an optional deadline, a progress ring, and a suggested daily amount. One tap adds that day's amount.
- **Tip of the day**: shown once on the first open each day, and always visible on the Goals tab. There are 100 tips in `lib/data/tips.dart`. Add more at the end of the list.
- **Settings**: theme (System, Light or Dark), currency, categories, erase all data.

Light and dark mode follow the phone by default. Picking Light or Dark in Settings overrides that, and picking System hands control back to the phone.

## Get an APK without installing anything

1. Create a new repository on GitHub and upload everything in this folder (keep the `.github` folder, it is the important one).
2. Open the **Actions** tab. The **Build Android APK** workflow runs on every push to `main` or `master`. You can also start it by hand with **Run workflow**.
3. When it finishes (about 5 to 10 minutes), open the run and download the **pocketwell-apk** file from **Artifacts**.
4. Unzip it, copy `app-release.apk` to your phone, and install it. Android will ask you to allow installs from your file manager or browser.

This APK is signed with a debug key, which is fine for installing on your own devices. The Play Store needs a proper release key and an app bundle (see below).

## Build on your own computer

You need Flutter (stable), Android Studio or the Android SDK, and Python 3.

```bash
flutter create --org com.stmedia --project-name pocketwell --platforms android,ios .
python3 tool/patch_android.py
flutter pub get
dart run flutter_launcher_icons
flutter test                # unit tests for the pure logic
flutter run                 # on a connected phone or emulator
flutter build apk --release # APK in build/app/outputs/flutter-apk/
```

`flutter create` only adds the `android` and `ios` folders. It does not touch the code in `lib`. The patch script adds the notification and fingerprint permissions, sets the app name, turns on the Android setting that the notification package needs, and switches `MainActivity` to a `FlutterFragmentActivity` with an AppCompat launch theme (the fingerprint prompt needs both). It is safe to run more than once.

## Before the Play Store

- Create a release keystore and add it to `android/app/build.gradle.kts` (the Flutter docs have the steps). Never commit the keystore or `key.properties`.
- Build a bundle with `flutter build appbundle --release`.
- The app id is `com.stmedia.pocketwell`. It cannot be changed after the first upload.
- You will need a privacy policy. The honest short version: no account, no server, no data leaves the phone.

## iOS

The `ios` folder is created by the same `flutter create` command, but building for iOS needs a Mac with Xcode (or a cloud build service) and an Apple Developer account. One extra step for reminders to show while the app is open: add this line to `application(_:didFinishLaunchingWithOptions:)` in `ios/Runner/AppDelegate.swift`:

```swift
UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
```

## How it is built

| Part | Choice |
| --- | --- |
| Storage | `sqflite` (SQLite on the phone) |
| State | One `Store` object (`ChangeNotifier`), no state package |
| Charts | Drawn by hand with `CustomPainter`, no chart package |
| Reminders | `flutter_local_notifications` (pinned to 17.2.4), scheduled locally |
| Backup | `share_plus` to save, `file_picker` to restore, one JSON file |
| App lock | Salted SHA-256 of the PIN in `shared_preferences`, `local_auth` for fingerprint |
| WhatsApp | `url_launcher` opens a `wa.me` link |
| Theme | Material 3, `ThemeMode.system` by default, choice saved in `shared_preferences` |

Money is stored as whole minor units (paise or cents) so totals never drift.

```
lib/
  main.dart, app.dart, theme.dart
  data/      db.dart, models.dart, store.dart, tips.dart,
             backup.dart (file format, CSV), search.dart (filter rules)
  services/  notifier.dart, app_lock.dart, files.dart
  screens/   shell, home, add_entry, category_entries, people, person,
             goals, settings, manage_categories, budgets, recurring,
             recurring_edit, search, lock
  widgets/   common, charts, dialogs, entry_tile, budget_row, lock_gate
  util/      format.dart, recurrence.dart
test/        format, recurrence, backup and CSV, search
tool/        patch_android.py, make_icons.py
```

## Planned for version 2

Reading bank SMS on Android (with the permission prompt), a home screen widget, multiple accounts (cash, bank, UPI), and automatic backups.
