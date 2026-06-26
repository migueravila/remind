# Terminal column printing

How `remind` turns a list of records into aligned, colored rows in the terminal — written down so the next CLI can print the same way. Derived from `Sources/core/ui.swift` (`OutputUtils`).

> View this file with `cat`, `bat`, `less -R`, `glow`, or on GitHub to see the colors in the example blocks. ANSI color is the whole point — it adapts to the user's terminal theme instead of hard-coding shades.

---

## 1. The shape of a row

A listing is one record per line. Every line is the same ordered sequence of fixed-position fields, so the eye reads each column straight down. Color encodes meaning; alignment comes from padding, not from separators.

```ansi
Unify CLI UIs                       [31m○[0m [2m4273[0m [34madmin[0m [33m!medium[0m [31msaturday[0m [31m⚑[0m
Update project packages             ○ [2m96BA[0m [34mwork [0m [33m!high  [0m tuesday [31m⚑[0m
Start new mosaic project            ○ [2m8125[0m [34mhome [0m [33m!none  [0m sunday
Cancel Gym                          [32m✓[0m [2m7779[0m [34madmin[0m [33m!none  [0m [2mno date[0m
```

Reading left to right, each row is built from these segments, joined by a **single space**:

| Segment | Width | Color | Notes |
| --- | --- | --- | --- |
| **Title** | constant `35` | default | left-aligned; truncates with `…` past 35 so later columns always start in the same place |
| **Status** | `1` | `red` ○ / `green` ✓ | open circle, green check when done; circle turns red when overdue |
| **Short id** | constant `4` | `dim` | first 4 chars of the record id — the handle you type into `done` / `edit` |
| **List** | measured | `blue` | padded to the widest list name in the current view |
| **Priority** | measured | `yellow` | padded to the widest priority label present |
| **Due date** | natural | `red` if overdue | humanized; `dim` when absent (`no date`) |
| **Markers** | natural | `dim` note · `red` ⚑ | optional, appended only when present |

Padded fields (title, list, priority) carry the alignment, so they come first. Variable, optional fields (date, markers) trail at the end where ragged width does no harm.

---

## 2. The one rule that makes it work

> **Pad the plain string, then color it.**

ANSI color is an invisible wrapper: `ESC[34m … ESC[0m` adds characters to the string but **zero width** on screen. If you pad a string that already contains color codes, the padding counts those invisible characters and your columns drift.

So always compute width and pad on the **plain** value, and apply color to the result. Width math sees only what the eye sees.

```swift
// wrong — padding counts the invisible escape codes
pad(blue(listName), width)

// right — pad first, color the already-padded text
blue(pad(listName, width))
```

The corollary: a **plain** (colorless) output mode is free, because the layout never depended on color. Strip the wrappers and the alignment still holds.

---

## 3. Columns from data, not magic numbers

One width is a constant: the title (`35`). The rest are measured from the rows about to be printed — scan the set, take the longest value per column, pad everyone to that. The table fits its contents and never reserves dead space for data that isn't there.

```swift
func maxWidth(_ rows, key) -> Int {
    rows.map { render($0[key]) }.map(\.count).max() ?? 0
}

let listW = maxWidth(rows, .list)      // "mike2026" -> 8
let prioW = maxWidth(rows, .priority)  // "!medium"  -> 7
```

---

## 4. A small, semantic palette

Color is meaning, not decoration. Each hue is one of the eight standard ANSI codes, so it adapts to the user's terminal theme. Six are enough; reusing the same color for the same meaning everywhere is what makes the output legible.

| Role | ANSI | Escape | Means |
| --- | --- | --- | --- |
| `dim` | SGR 2 | `ESC[2m` | secondary / inert — ids, `no date`, note markers |
| `blue` | SGR 34 | `ESC[34m` | category — the list a record belongs to |
| `yellow` | SGR 33 | `ESC[33m` | attention / priority |
| `red` | SGR 31 | `ESC[31m` | urgent — overdue, flagged, errors |
| `green` | SGR 32 | `ESC[32m` | done / success |
| `cyan` | SGR 36 | `ESC[36m` | neutral info |
| `reset` | SGR 0 | `ESC[0m` | close every wrapper — never let color bleed |

Here is the palette itself, rendered:

```ansi
[2mdim    — ids, no date, note markers[0m
[34mblue   — list / category[0m
[33myellow — priority[0m
[31mred    — overdue, flagged, errors[0m
[32mgreen  — done / success[0m
[36mcyan   — neutral info[0m
```

Wrap each color in a one-line helper so call sites stay readable. The wrapper always closes with reset:

```swift
func blue(_ s: String) -> String { "\u{001B}[34m" + s + "\u{001B}[0m" }
func dim(_ s: String)  -> String { "\u{001B}[2m"  + s + "\u{001B}[0m" }
// …one per role. Same shape, different code.
```

### Glyphs

A tiny fixed vocabulary of single-width marks. Pair each with color so the meaning survives in grayscale and for colorblind readers.

| Glyph | Use |
| --- | --- |
| `○` `✓` | row status: open / complete |
| `⚑` | flagged |
| `✔` `✗` `⚠` `ℹ` | feedback lines: success / error / warning / info |
| `➤` | interactive prompt |

---

## 5. One pipeline, four outputs

The render path is a straight line. A single format switch at the end decides how the already-sorted records are emitted — the data and ordering never change between modes.

```
fetch  ->  sort  ->  measure widths  ->  format (per mode)
```

| Mode | For | Looks like |
| --- | --- | --- |
| `standard` | a human at a TTY | aligned, colored columns (the default) |
| `plain` | pipes — `grep`, `awk` | no color, `|`-delimited fields |
| `json` | scripts & other tools | pretty, sorted keys, ISO-8601 dates |
| `quiet` | counts in conditionals | just the number of rows |

```text
$ remind all --plain
[ ] Unify CLI UIs * | admin | saturday
[ ] Update project packages * | work | tuesday
[x] Cancel Gym | admin | no date
```

Branching early keeps each mode honest: `plain` stays scriptable, `standard` stays pretty, and neither compromises for the other.

---

## 6. Sort, then humanize

**Sort before you print.** Ordering is part of the display. Sort once, by a clear cascade, so the same data always lands the same way:

1. Open before completed
2. Then by due date, soonest first
3. Dated before undated
4. Then higher priority first

**Humanize the date.** Absolute timestamps are noise. Render relative to now, lowercase, and fall back to a calendar date only when the distance is large:

| Distance from today | Shows |
| --- | --- |
| −1 / 0 / +1 day | `yesterday` · `today` · `tomorrow` |
| within the next 7 days | weekday name (e.g. `saturday`) |
| within the last 7 days | `N days ago` |
| further out | short date (e.g. `jul 4`) |

---

## 7. Porting it

The whole system is four primitives and an assembly step. In any language, build these and you'll match the look:

```text
// 1 — truncate to a hard cap with an ellipsis
truncate(s, max)  = s.len <= max ? s : s[0..max-1] + "…"

// 2 — left-pad to width, on the PLAIN string
pad(s, width)     = s + " ".repeat(max(0, width - s.len))

// 3 — color wrappers (reset every time)
color(code, s)    = "ESC[" + code + "m" + s + "ESC[0m"

// 4 — measure a column across the rows you're about to print
maxWidth(rows, f) = rows.map(f).map(len).max() ?? 0

// assemble — pad first, color second, join with one space
renderRow(r, w) = [
    pad(truncate(r.title, 35), 35),
    r.done ? green("✓") : statusGlyph(r),
    dim(pad(r.id[0..4], 4)),
    blue(pad(r.list, w.list)),
    yellow(pad(r.priority, w.prio)),
    dateText(r),
].join(" ")
```

---

## 8. The rules, in one place

1. **Pad the plain string, then color.** ANSI codes are zero width. Measure and pad what the eye sees, wrap color around the result.
2. **Alignment lives in padding, not separators.** One space between columns is enough once every field is padded. Bullets and dots are noise.
3. **Padded fields first, ragged fields last.** Fixed and measured columns carry the grid; optional natural-width fields trail where they can't misalign anything.
4. **Measure widths from the visible rows.** Only the title is a constant. Everything else fits the data in front of you.
5. **Truncate to a cap with an ellipsis.** A runaway title must not push the columns sideways. Cut it and signal the cut.
6. **One color per meaning, from the 8 ANSI colors.** Reuse colors consistently and let the terminal theme own the exact shades.
7. **Encode state twice — shape and color.** A `red ○` vs a `green ✓` survives grayscale, colorblindness, and a plain pipe.
8. **Sort once, before formatting.** Order is display. Decide it in one place so every mode agrees.
9. **Humanize time.** `tomorrow` and `3 days ago` beat a timestamp for a human at a prompt.
10. **Always offer a plain and a JSON mode.** If the layout never relied on color, colorless output is free — and pipeable output makes the tool composable.

---

*Derived from remind · `Sources/core/ui.swift` — model → sort → measure → format → print*
