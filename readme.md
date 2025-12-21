# remind

A command-line interface for Apple Reminders. Built for terminal natives who prefer keyboard-driven workflows over GUI interactions.

## Installation

### From Source

```bash
git clone https://github.com/mendicant/remind.git
cd remind
make install
```

### Requirements

- macOS 13.0 or later
- Swift 6.0 or later
- Xcode Command Line Tools

### Permissions

On first run, macOS will prompt for Reminders access. Grant permission in **System Settings > Privacy & Security > Reminders**.

## Usage

### Quick Reference

```
remind                          Show today's reminders
remind [filter]                 Show reminders by filter
remind list [name]              Show or create list
remind add [title]              Add a reminder
remind complete [id...]         Mark reminders complete
remind edit [id]                Edit a reminder
remind delete [id...]           Delete reminders
```

---

## Show Reminders

Display reminders based on time filters.

```bash
remind                      # Today's reminders (default)
remind today                # Today's reminders
remind tomorrow             # Tomorrow's reminders
remind week                 # This week's reminders
remind overdue              # Overdue reminders
remind upcoming             # All upcoming reminders
remind flag                 # Flagged reminders
remind 25-12-24             # Specific date (DD-MM-YY)
```

### Aliases

```bash
remind t                    # tomorrow
remind w                    # week
remind o                    # overdue
remind u                    # upcoming
remind f                    # flagged
```

---

## Manage Lists

View, create, rename, and delete reminder lists.

```bash
remind list                 # Show all lists
remind lists                # Show all lists (alias)
remind l                    # Show all lists (alias)
```

### Show List Reminders

```bash
remind list Work            # Show reminders in "Work" list
remind list "Shopping List" # Use quotes for names with spaces
```

### Create List

If the list does not exist, it will be created.

```bash
remind list Projects        # Creates "Projects" list
```

### Rename List

```bash
remind list Work -r "Office"        # Rename "Work" to "Office"
remind list Work --rename "Office"
```

### Delete List

```bash
remind list Work -d                 # Delete "Work" list
remind list Work --delete
```

---

## Add Reminders

Create new reminders interactively or with flags.

### Interactive Mode

```bash
remind add                  # Start interactive prompt
remind a                    # Alias
```

Interactive mode prompts for:
- Title
- List selection
- Due date (optional)
- Notes (optional)
- Priority

### Direct Mode

```bash
remind add "Buy groceries"
remind add "Call mom" -l Personal
remind add "Meeting" -l Work -d tomorrow
remind add "Urgent task" -l Work -d 2024-12-25 -p high
remind add "Review docs" -l Work -f
```

### Flags

| Flag | Long | Description |
|------|------|-------------|
| `-l` | `--list` | Target list name |
| `-d` | `--due` | Due date |
| `-p` | `--priority` | Priority (none, low, medium, high) |
| `-f` | `--flag` | Mark as flagged |
| `-n` | `--notes` | Add notes |

### Date Formats

The `--due` flag accepts multiple formats:

```bash
-d today
-d tomorrow
-d yesterday
-d 2024-12-25
-d 25-12-24
-d "2024-12-25 14:30"
```

---

## Complete Reminders

Mark one or more reminders as complete.

```bash
remind complete 1           # Complete reminder #1
remind complete 1 2 3       # Complete multiple reminders
remind complete 4A83        # Complete by partial ID
remind c 1                  # Alias
remind done 1               # Alias
```

### Identifier Types

- **Number**: Position in the displayed list (1-based)
- **Partial ID**: First 4+ characters of the reminder ID
- **Full ID**: Complete reminder identifier

---

## Edit Reminders

Modify existing reminders.

```bash
remind edit 1               # Edit reminder #1 interactively
remind e 1                  # Alias
```

### Edit with Flags

```bash
remind edit 1 -t "New title"
remind edit 1 -l "New List"
remind edit 1 -d tomorrow
remind edit 1 -p high
remind edit 1 -f            # Toggle flagged status
```

### Flags

| Flag | Long | Description |
|------|------|-------------|
| `-t` | `--title` | New title |
| `-l` | `--list` | Move to different list |
| `-d` | `--due` | New due date |
| `-p` | `--priority` | New priority |
| `-f` | `--flag` | Toggle flagged |
| `-n` | `--notes` | New notes |

---

## Delete Reminders

Remove one or more reminders.

```bash
remind delete 1             # Delete reminder #1
remind delete 1 2 3         # Delete multiple reminders
remind delete 4A83          # Delete by partial ID
remind d 1                  # Alias
remind rm 1                 # Alias
```

Deletion requires confirmation. Use `--force` to skip:

```bash
remind delete 1 --force
remind delete 1 -y
```

---

## Output Format

### Default Output

Reminders are displayed with:
- Title (truncated to 35 characters)
- Completion status indicator
- Short ID (first 4 characters)
- List name
- Priority level
- Due date (relative: "today", "tomorrow", "3 days ago")
- Notes indicator

Example:
```
Buy groceries                      o 4A83 | Shopping | !none   | tomorrow
Call mom                           o 7B21 | Personal | !high   | today
Completed task                     * 9C45 | Work     | !medium | yesterday
```

### Machine-Readable Output

For scripting and piping:

```bash
remind --json               # JSON output
remind --plain              # No colors, plain text
remind --quiet              # Minimal output
```

---

## Configuration

### Environment Variables

```bash
REMIND_DEFAULT_LIST="Personal"      # Default list for new reminders
REMIND_DATE_FORMAT="DD-MM-YY"       # Preferred date format
REMIND_COLOR="auto"                 # auto, always, never
```

### Config File

Configuration can be stored in `~/.config/remind/config.yaml`:

```yaml
default_list: Personal
date_format: DD-MM-YY
color: auto
confirm_delete: true
```

---

## Examples

### Daily Workflow

```bash
# Morning: Check today's tasks
remind

# Add task from quick thought
remind add "Review PR" -l Work -d today

# Complete tasks as you go
remind c 1 2

# End of day: Check what's left
remind overdue
```

### Project Management

```bash
# Create project list
remind list "Project Alpha"

# Add project tasks
remind add "Design review" -l "Project Alpha" -d monday
remind add "Implementation" -l "Project Alpha" -d friday -p high
remind add "Testing" -l "Project Alpha"

# View project tasks
remind list "Project Alpha"
```

### Scripting

```bash
# Count overdue reminders
remind overdue --json | jq length

# Export all reminders
remind upcoming --json > backup.json

# Complete all in a list
remind list Work --json | jq -r '.[].id' | xargs remind complete
```

---

## Keyboard Shortcuts

In interactive mode:

| Key | Action |
|-----|--------|
| Up/Down | Navigate options |
| Enter | Select |
| Esc | Cancel |
| Type | Filter/search options |
| Left/Right | Navigate weeks (date picker) |

---

## Troubleshooting

### "Access to Reminders denied"

1. Open System Settings
2. Go to Privacy & Security > Reminders
3. Enable access for Terminal (or your terminal app)

### Reminders not syncing

The CLI uses the local Reminders database. Changes sync via iCloud automatically if enabled in System Settings.

### Command not found

Ensure `/usr/local/bin` is in your PATH:

```bash
echo $PATH | grep -q /usr/local/bin || echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
```

---

## Development

### Build

```bash
make build          # Release build
make dev            # Format, lint, test, build
swift build         # Debug build
```

### Test

```bash
make test           # Run tests
swift test          # Run tests directly
```

### Code Quality

```bash
make format         # Format with swiftformat
make lint           # Lint with swiftlint
```

---

## License

MIT License. See LICENSE file for details.

---

## Contributing

Contributions are welcome. Please open an issue to discuss changes before submitting a pull request.
