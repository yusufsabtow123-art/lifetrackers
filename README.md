# Life Tracker

A local-first Flutter life tracker for Windows, macOS, Android, and iOS.
The active verification targets are Windows and Android; macOS and iOS remain
included but unverified until they are built on a Mac.

## Included proof

- Responsive goal board with Ideas, Planned, Active, Paused, and Completed visible by default.
- Narrow Android screens use a Mini board map that keeps every visible status discoverable above a readable selected-column list; tapping the map opens a board-only full-screen view, while wide desktop screens retain the Trello-like board.
- Optional Abandoned column enabled in Settings without changing hidden abandoned goals.
- Name-only **Capture an idea** flow in Ideas and mouse/touch card movement.
- Amount-based **Add a plan** flow during creation or later, with starting progress, a start date, and a deadline. Starting progress accepts work already completed or a current position counted down from the total.
- One unified **Progress** section with the amount target and checklist together, one focused **Log amount** action, and direct step checkboxes.
- Percentage plus amount display, schedule pace in real units, and On track / At risk / Behind health.
- Automatic local saving, one-step Undo for the latest reversible board action, and plain-language explanations for every column.
- Android reminder notifications with app identity, full-screen delivery support,
  Done / Not done / Delay actions, test delivery, and device-status diagnostics.
- Android home-screen widgets backed by the same local goal data.
- One readable Markdown file per goal; the board loads those files automatically on startup.
- Recoverable Trash with restore, explicit permanent-delete confirmation, and one-step Undo.
- Follow-system, Light, and Dark appearance modes remembered locally on the device.
- Backward-compatible loading of old blocked Markdown as Paused.

The original goal board now sits beside Today, Tasks, Calendar, Personal and
Shared Spaces, and an AI placeholder. Active goal plans create daily actions
automatically; those actions appear in Today and Calendar.

Tasks, calendar entries, blocked times, and local space details are saved in a
readable `life-tracker.md` file. The calendar accepts changing blocked-time
schedules pasted from a sheet in `date, start, end, name` form, and one switch
hides or shows all blocked time.

Private use works offline. Online invitations, multi-device syncing, and paid
additional Shared Spaces require the future online service and are not faked in
this build. The AI page deliberately says **Work in progress**.

## Local files

Goals are stored under the app's documents directory in `Goals POC/goals`.
Goals moved to Trash are stored in the readable `Goals POC/goals/trash` subfolder.
Each `.md` file contains structured front matter for the board plus a readable
Markdown history section. The folder path is visible from the folder button in
the app header, and the button opens that folder on Windows.

## Verify

```powershell
flutter analyze
flutter test
```

To build the active targets, install:

- Visual Studio 2022 with **Desktop development with C++** for Windows.
- Android Studio plus the Android SDK for Android.
- Windows Developer Mode, which Flutter plugins need to create symlinks.

Then run:

```powershell
flutter build windows --release
flutter build appbundle --release --analyze-size
flutter build apk --release --split-per-abi
```

## Build without local toolchains

The repository workflow at .github/workflows/build-apps.yml builds downloadable Android and Windows packages on GitHub. It provides the preferred arm64 APK separately from compatibility packages, records Android package sizes, and rejects an arm64 APK above the documented 25 MiB budget. This is the preferred proof-of-concept build path when the local computer is short on storage or does not have Visual Studio/Android tooling installed.
