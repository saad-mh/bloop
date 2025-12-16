# Simple Flutter To-Do App — Technical Plan

## 1. Purpose & Vision
Build a clean, reliable, local-first to-do app in Flutter for personal daily use.  
The app focuses on clarity, low friction, and trust. Tasks are easy to add, easy to complete, and never accidentally lost. Completed tasks are hidden from the main view but remain accessible as history.

Core principles:
- Simple UX, minimal taps
- Offline-first, no account required
- Predictable reminders
- Data safety (nothing disappears silently)
- Easy to extend later (cloud sync, widgets, AI input)

---

## 2. Core Features
- Create, edit, delete tasks
- Optional date and time
- Optional reminders
- Optional repeat rules
- Priority levels
- Tags for grouping and filtering
- Mark tasks as completed
- Completed tasks removed from main list but stored
- Local notifications
- Search, filter, and sort
- Basic settings and backups

---

## 3. Task Data Model
Each task is a single canonical object. Completed tasks are not deleted; they are filtered out of the active view.

### Task Fields
- `id` (String, UUID)
- `title` (String, required)
- `notes` (String?, optional)
- `dueDateTime` (DateTime?, nullable)
- `allDay` (bool)
- `recurrence` (enum or string rule)
- `reminderBefore` (Duration?, nullable)
- `priority` (enum: low, medium, high)
- `tags` (List<String>)
- `isCompleted` (bool)
- `createdAt` (DateTime)
- `updatedAt` (DateTime?)
- `completedAt` (DateTime?)
- `notificationId` (int?, stored to cancel reminders)

### Priority Enum
- LOW
- MEDIUM
- HIGH

### Recurrence Options
- None
- Daily
- Weekly
- Monthly
- Yearly
- Custom (future extension)

---

## 4. Data Storage Strategy
### Primary Choice: Hive
Reasoning:
- Lightweight and fast
- No SQL boilerplate
- Works fully offline
- Ideal for small to medium task lists

Implementation:
- One Hive box: `tasks`
- Store all tasks with `isCompleted` flag
- Filter in memory for active vs completed
- Optional second box later: `task_history` for recurring instances

Backup:
- Export all tasks to JSON
- Import JSON to restore data
- Manual user-controlled backups

---

## 5. State Management
### Riverpod (recommended)
Why:
- Predictable state flow
- Scales cleanly
- Testable
- No widget tree dependency

Providers:
- TaskListProvider (all tasks)
- ActiveTasksProvider (filtered)
- CompletedTasksProvider (filtered)
- SettingsProvider
- TagsProvider

---

## 6. Notifications & Reminders
### Library
- `flutter_local_notifications`
- `timezone`

### Reminder Logic
- Reminder time = `dueDateTime - reminderBefore`
- Notifications scheduled using zoned time
- Store notification ID in task
- On edit, cancel and reschedule
- On completion, cancel notification

### Repeat Tasks
Two modes (initially simple mode):
- On completion:
  - Calculate next due date
  - Update same task
  - Reschedule notification
- Optional: store completion timestamp in history later

---

## 7. Screens & Navigation
Use a Bottom Navigation Bar.

### 1. Home Screen (Active Tasks)
- Default landing screen
- Shows active (not completed) tasks
- Sections:
  - Overdue
  - Today
  - Upcoming
  - No date
- Sorting:
  - By date
  - By priority
  - By creation time
- Filters:
  - Tags
  - Priority
- Actions:
  - Tap → Edit
  - Swipe → Complete / Delete / Snooze
  - Long press → Multi-select

### 2. Add / Edit Task Screen
Opened via FAB or task tap.

Fields:
- Task title (required)
- Notes (optional)
- Date picker
- Time picker
- All-day toggle
- Repeat selector
- Reminder selector
- Priority selector
- Tags input (chips)

Behavior:
- Validate title
- Warn if reminder is in the past
- Save persists task and schedules reminder

### 3. Completed Tasks Screen
- Shows completed tasks only
- Sorted by completion date
- Actions:
  - Restore task
  - Permanently delete
- Optional auto-clear setting

### 4. Tags Screen (Optional)
- Create, rename, delete tags
- Show task count per tag
- Tap to filter tasks

### 5. Settings Screen
- Default reminder time
- Default priority
- Enable/disable notifications
- Auto-clear completed tasks
- Export / Import data
- Theme (light/dark/system)
- About / version info

---

## 8. Navigation Flow
- App launch → Home
- FAB → Add Task
- Task tap → Edit Task
- Bottom nav → switch screens
- Back always returns safely without data loss

---

## 9. UX Behavior Rules
- Tasks without date stay visible indefinitely
- Tasks due today remain at top
- Overdue tasks highlighted subtly
- Completing a task removes it instantly from Home
- No destructive action without undo option
- SnackBars for confirmation

---

## 10. Folder Structure
lib/
├── models/
│ ├── task.dart
│ └── recurrence.dart
├── services/
│ ├── storage_service.dart
│ ├── notification_service.dart
│ └── recurrence_service.dart
├── providers/
│ ├── task_provider.dart
│ ├── settings_provider.dart
│ └── tags_provider.dart
├── ui/
│ ├── screens/
│ │ ├── home_screen.dart
│ │ ├── add_edit_task_screen.dart
│ │ ├── completed_screen.dart
│ │ ├── settings_screen.dart
│ │ └── tags_screen.dart
│ └── widgets/
│ ├── task_tile.dart
│ ├── priority_indicator.dart
│ └── tag_chip.dart
├── utils/
│ ├── date_utils.dart
│ └── id_generator.dart
└── main.dart


---

## 11. Edge Cases & Constraints
- Handle notification permissions gracefully
- Prevent duplicate notification scheduling
- Ensure reminders survive app restart
- Handle device reboot on Android
- Prevent accidental deletion
- Support empty states cleanly
- Handle timezone changes safely

---

## 12. MVP Scope (Phase 1)
Must-have before release:
- Create/edit/delete tasks
- Local persistence
- Mark complete
- Completed archive
- Date/time selection
- Local notifications
- Basic settings
- JSON export

---

## 13. Phase 2 Enhancements
- Cloud sync (Firebase or Supabase)
- Widgets (home screen)
- Natural language task input
- Smart reminders
- Analytics (task streaks)
- Shared lists
- Theming and animations

---

## 14. Technical Checklist Before Coding
- Initialize Flutter project
- Add Hive + adapters
- Configure notifications and timezone
- Set up Riverpod providers
- Build core screens
- Test reminders thoroughly
- Test cold start, reboot, permission denial
- Add backup/export

---

## 15. Success Criteria
- Tasks never disappear unexpectedly
- Reminders fire reliably
- App works fully offline
- UI feels fast and calm
- Easy to explain and use without instructions
