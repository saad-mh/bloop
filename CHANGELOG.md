# Changelog

## 2.0.0 (2026-10-18)

A full redesign. The 2.0 look is monochrome (grayscale and ink) in light and dark; colour is planned for a later build (#16). Existing features carry over.

### New look and navigation

- Hand-built monochrome theme with Fraunces headings and Work Sans text, bundled so the app still works offline.
- A floating pill switches between Tasks and Focus, with a separate New task button beside it. While a Focus session runs, the pill shows the time left.
- Settings opens from the gear in the home header. Completed is no longer a tab.
- New app icons (the Ring and pop set), including themed Android icons.

### Tasks

- Home header with a time-of-day greeting, search, and tag filter chips that filter every section at once.
- The list is grouped into Overdue, Today, Upcoming and Whenever, with collapsible headers and counts. Completed sits at the bottom, collapsed.
- Redesigned task rows: date and time meta line, tag pill, flag for high priority, bell for reminders. Tasks that are due now or within the hour are highlighted without relying on colour.
- Tap a row to act in place: Focus, Snooze 1h, Tomorrow or Edit.
- Add / Edit task is a full-screen page with Today / Tomorrow / date chips, time, reminder, priority and tags, and a button that rides above the keyboard. Closing with unsaved text asks first.

### Focus

- Redesigned Focus screens (Ready, Running, Time's up) are now the default, and a session can start straight from a task.
- Sounds and scenery are no longer bundled. The app asks, then downloads them the first time you pick them, which makes the install far smaller.

### Tags and settings

- Tag management shows open-task counts, renames everywhere, and shows how many tasks a delete affects. Empty and duplicate names are rejected.
- Settings are grouped into Profile (your name), Focus (default length), Tags, Notifications and Advanced. Everything from 1.x is still there under Advanced.

### First run and permissions

- Onboarding for new users: your name, a few starter tags, and an example task with confetti.
- A reworked notification permission prompt.

### Polish and fixes

- Dark mode, large-text, 48dp touch targets, screen-reader labels and contrast checked across screens; subtle motion on section collapse and row expand.
- The home greeting shrinks to the largest size that fits before falling back to "Tasks".
- Fixed a stale Focus shell test and a few analyzer lints.

### Notes for upgrading

- This release is signed with a new key. Android will refuse to install it over 1.0.x ("App not installed"). In 1.0.x use Settings > Export data (copies your tasks as JSON), paste it somewhere safe, uninstall 1.0.x, install 2.0.0, then use Import data. Future updates from 2.0.0 onwards install normally.

## 1.0.5

See the [1.0.5 release](https://github.com/saad-mh/bloop/releases/tag/v1.0.5) and earlier releases.
