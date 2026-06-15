# MenuBarFolder 📁

**A folder that lives in your menu bar — and is perfectly happy about it.**

You know that one folder you open forty times a day? Downloads. Screenshots.
That sacred pile of "I'll sort this later." MenuBarFolder pins it (or several of
them) right into your menu bar, so it's always one click away — no Finder
window, no Spotlight gymnastics, no `cd` into the void.

It's a small, slightly silly, genuinely useful experiment. Nothing more,
nothing less.

> Home: **http://ctrl8.com/MenuBarFolder** · by **iLya Os**
> (github.com/ilya000) · **MIT** licensed · made for macOS

---

## What it actually does

- 📂 **Pins folders to the menu bar.** Each one becomes its own little icon —
  a folder glyph wearing the folder's first two letters like a name tag
  (`Ap` for *Applications*, `Do` for *Downloads*, you get it).
- 🖱️ **Click a file → it opens.** Just like a Finder double-click. Subfolders
  unfold into nested submenus, as deep as you dare to go.
- 🐘 **Eats huge folders for breakfast.** Got a folder with 40,000 photos from
  the last decade? It reads in the background (no spinning-beachball freeze),
  remembers what it found, and shows the first 250 — the rest politely fold
  into a *“…open in Finder”* line.
- 🎛️ **Sorts how you like.** By name, date added, date modified, or size.
  Folders on top, or all mixed together. Your call.
- 🚀 **Starts at login** (if you tick the box) so your folders are waiting for
  you every morning.
- 🧠 **Remembers everything.** Your folders and settings survive reboots. Set
  it once, forget it forever.
- 👻 **No Dock icon, no window clutter.** One quiet little process running the
  whole show.

## Get it running

You'll need macOS 13+ and a Swift toolchain (Xcode, or the command-line tools).

```bash
git clone https://github.com/ilya000/MenuBarFolder.git
cd MenuBarFolder
swift build -c release
.build/release/MenuBarFolder
```

A folder picker pops up on first launch — choose your victim. Add more, change
sorting, or flip *Start at Login* from **Settings… (⌘,)** in any icon's menu.

Feeling impatient? Seed a few folders straight from the command line:

```bash
.build/release/MenuBarFolder /Applications ~/Pictures ~/Downloads
```

They'll be remembered, so next time a plain `MenuBarFolder` brings them all
back.

## The menu, briefly

```
<Folder name>
────────────
…your files…              ← click to open · hover a subfolder to expand
────────────
Open “<Folder>” in Finder
Settings…                 ⌘,
Quit                      ⌘Q
```

Everything fancier — the folder list, sorting, grouping, Start at Login, and an
**About** tab — lives in the **Settings** window, so the menus stay tidy.

## Under the hood (for the curious)

- Folders are saved as bookmarks, so they keep working even if you move or
  rename them.
- *Start at Login* writes a tiny LaunchAgent
  (`~/Library/LaunchAgents/com.ctrl8.menubarfolder.plist`) pointing at the
  binary — no `.app` bundle required.
- Directory reads happen off the main thread, get cached, and are capped per
  level so the menu stays instant.
- Hidden dot-files are skipped. App bundles (`.app`, `.framework`, …) are
  treated as openable items, not folders to rummage through.

| File | Job |
|------|-----|
| `main.swift` | App delegate — owns the icons, the picker, CLI seeding. |
| `FolderPin.swift` | One menu-bar icon + menu per folder. |
| `FolderMenu.swift` | Background reading, sorting, lazy submenus. |
| `FolderStore.swift` | Remembers your folder list. |
| `Prefs.swift` | Global sort / grouping settings. |
| `LoginItem.swift` | Start-at-Login via LaunchAgent. |
| `StatusIcon.swift` | Draws the folder-with-two-letters icon. |
| `Settings.swift` | Settings window + About tab (SwiftUI). |
| `AppInfo.swift` | Who/what/which-version. |

## Status

Experimental and proudly so. It works, it's small, it scratches a real itch.
If it breaks, it breaks quietly — and you can always just open Finder. 🙂

## License

MIT — see [LICENSE](LICENSE). Free and open source.
Copyright © 2026 Ilya Osipov (iLya Os).
