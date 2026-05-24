# AGENTS.md

## Quick start

```bash
make build          # release binary → .build/release/remind
make test           # runs `swift test` — succeeds but there are **no tests**
make format         # swiftformat --config .format Sources/
make lint           # swiftlint (CI uses `swiftformat --lint` instead)
make dev            # format → lint → test → build
./.build/release/remind --help
```

## Targets

Two SwiftPM targets in `Package.swift`:

- **core** — library (`Sources/core/`). `public` API.
  - `models.swift` — `Reminder`, `ReminderList`, `Priority`, `OutputFormat`, `ShowOptions`, `ViewSpec`, `ViewState`, `ProgramError`.
  - `manager.swift` — EventKit wrapper (`Manager`).
  - `storage.swift` — `Config` (YAML at `~/.config/remind/config.yaml`) and `ViewStateStore` (JSON at `~/.config/remind/state.json`).
  - `ui.swift` — terminal I/O: `Constants`, `Terminal`, `KeyInput`, `InputUtils`, `OutputUtils`.
  - `utils.swift` — `DateUtils` and `IDResolver`.
- **remind** — executable (`Sources/remind/`). Depends on `core` and `ArgumentParser`.
  - `app.swift` — `@main` `Remind`, `OutputOptions`, `ArgDispatcher`.
  - `view.swift` — `ShowCommand`, `ListsCommand` (read views; persist `ViewState`).
  - `reminder.swift` — `AddReminderCommand`, `EditReminderCommand`, `CompleteReminderCommand`, `DeleteReminderCommand`.
  - `list.swift` — `CloseCommand`, `RenameCommand`, `CleanCommand`.

Subcommands are registered in `app.swift` via `CommandConfiguration.subcommands`. Add new ones there.

## Architecture quirks

- **`ArgDispatcher.rewrite()`** (`app.swift`): If the first non-flag arg isn't a reserved word or date, it's treated as a list name. `remind Work` → `remind show --list Work`. `remind Work add "x"` → `remind add --list Work "x"`. `done` is overloaded by arity: `remind done` (no args) shows completed; `remind done 1 2` completes those ids. Reserved sets: filter verbs (`today`, `tomorrow`, `upcoming`, `flag`, `done`, `all`), list verbs (`list`, `lists`, `l`), manipulator verbs (`add`, `edit`, `complete`, `delete`, `close`, `rename`, `clean`).
- **Last view persistence**: every read command writes `~/.config/remind/state.json` (a `ViewSpec` + an ordered id snapshot). Manipulator commands (`done`/`delete`/`edit`/`add`) without an explicit `--list` resolve numeric ids against that snapshot and fall back to the last-viewed list when adding. See `ViewStateStore` in `storage.swift`.
- **Flag is priority-derived**: the public macOS EventKit SDK does not expose `EKReminder.isFlagged` (KVC key `flagged` crashes). `Reminder.isFlagged` is a computed `priority != .none`. `--flag` on `add`/`edit` maps to `priority = .high`; `--unflag` maps to `.none`. The `flag` filter returns reminders where `priority != .none`.
- **No tests exist** — `Sources/` only, no `Tests/` directory. `make test` succeeds trivially.
- **Config**: `~/.config/remind/config.yaml` merged with `REMIND_*` env vars (`REMIND_DEFAULT_LIST`, `REMIND_DATE_FORMAT`, `REMIND_COLOR`). See `Config.load()` in `storage.swift`.
- **EventKit**: macOS only, needs first-run Reminders permission. `Manager` uses `withCheckedThrowingContinuation` for callback-based EK APIs.

## CI

`macos-14` runners, Xcode 16.2. Two workflows:
- `pr.yml` — `swift build` + `swiftformat --lint Sources/` (note: formatting check, not swiftlint)
- `release.yml` — release build + tar + GH release on push to master

## Conventions

- **No comments, no emojis** in source code.
- **4-space indent, 80-char width**, import sorting (`.format`).
- **Swift 6.0 strict concurrency** — models are `Sendable`, use async/await.
- **Lowercase filenames** (`readme.md` not `README.md`).

## Related instruction files (worker context, not in repo)

- `CLAUDE.md` in workspace root and `.claude/rules` — additional project rules on style and patterns.
