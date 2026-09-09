# Android v0.14.1 design update

Reference: the six approved coral/charcoal sheets catalogued in REFERENCE-INDEX.md. Older purple and monochrome experiments are not the reference.

## Implemented

- Compact Android page headings and coral selected navigation, thin task completion icons, charcoal surfaces and neutral secondary buttons.
- Today action hero, daily timeline and completed group; task rows with separate completion and edit actions.
- Full-screen task editor, separate date/time controls, repeat, goal link, location, notes and existing dictation access. Editing an undated task preserves its null date.
- Raised goal-board columns/cards with progress rings, compact board/list/filter controls, existing dragging and edge scrolling retained.
- Full-screen mobile goal details: next action, progress ring/amount/pace/deadline, log progress, steps and collapsed details. Progress-display preference still honored.
- Compact calendar header/week strip, full-height timed grid, circular coral add button. Month view, block visibility and schedule import remain accessible.
- Personal/shared-space tabs, member row and assignments for existing local spaces. Compact settings navigation. AI remains a placeholder with a working link to manual goals.
- Motion transitions respect the OS reduced-animation setting where applied.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 103 tests passed.
- Includes true 320px mobile viewport, task completion/count/edit, undated-task preservation, calendar create/edit/color, month overflow, board dragging and data recovery tests.
- Android 15 x86_64 emulator: signed release installed with `adb install -r`, without uninstalling or clearing storage. Existing saved goals and task remained visible.
- Actual emulator screenshots inspected for Today, Tasks, task editing, Calendar, Settings, Spaces and goal details. Screenshots are local QA evidence, not public assets, since they show existing app data.
- ARM64 package: `app.localfirst.goal_tracker_poc.dev`, version name `0.14.1-dev`, version code `4021`, minimum SDK 24. Existing package name and signing identity retained solely for upgrade compatibility.
- Signing certificate SHA256: `23d1312e09cd0771f964be3fc5a3e0bd52098d48215264027fbf6fb40ecbac2e`.
- APK: 19,751,443 bytes; SHA256 `ed3ffa7e48034a1be78a94f1cb05417d5cd4bc6d2cceac782a00d7fa04702169`.

## Release and limits

Published Android APK: https://github.com/yusufsabtow123-art/lifetrackers/releases/tag/v0.14.1

No Windows binary in this release. This is a functional adaptation of the approved layouts, not a claim of pixel-identical rendering on every device. Existing controls/settings remain available; mockup-only features such as online collaboration, analytics, and AI were not invented or silently enabled. Image attachment parity in task notes and a dedicated accessibility settings section remain outside this visual update. Physical Samsung testing is not claimed. Never uninstall or clear storage to work around an upgrade issue without the user's explicit approval.
