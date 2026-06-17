# MenuBarFolder

**Keep your most-used folders one click away — right in the macOS menu bar.**

We all have *that* folder. Downloads. Screenshots. The desktop graveyard of
"I'll sort this later." You open it dozens of times a day, and every time it's
the same little ritual: find a Finder window, click around, sigh.

MenuBarFolder turns that ritual into a single click. Pin any folder — or several
— to your menu bar, and its contents are always a tap away: open files in their
default app, walk into subfolders through nested submenus, all without a Finder
window in sight. Each pinned folder gets its own tidy icon, and the whole setup
is remembered across reboots.

It's deliberately small and a little playful, but it earns its place in the
menu bar every single day. An experiment that turned out genuinely handy.

> Home: **http://ctrl8.com/MenuBarFolder** · by **iLya Os** (github.com/ilya000)
> · **MIT** licensed · macOS 13+

---

## What it does

- **Pins folders to the menu bar.** Each one becomes its own icon — a folder
  glyph wearing the folder's first two letters like a name tag (`Ap` for
  *Applications*, `Do` for *Downloads*, and so on).
- **Click a file, it opens** — just like a Finder double-click. Subfolders
  unfold into nested submenus, as deep as you need to go. Hold **Option** to
  reveal a file in Finder instead.
- **Browser bookmarks too.** Pin a Chrome / Brave / Edge / Vivaldi profile and
  browse its bookmark tree from the menu bar — with favicons. Clicking a
  bookmark opens it in that browser; Option copies the link. Multiple profiles
  of one browser get distinct two-letter badges.
- **Handles huge folders.** A folder with 40,000 photos from the last decade?
  It reads in the background (no beachball freeze), caches what it found, and
  shows the first 250 — the rest fold into a single *"open in Finder"* line.
- **Sorts how you like.** By name, date added, date modified, or size; folders
  on top or all mixed together.
- **Starts at login** (optional) so your folders are ready every morning.
- **Remembers everything.** Folders and settings survive reboots. Set it once,
  forget it.
- **No Dock icon, no window clutter.** One quiet process runs the whole show.

## Download

**[Download MenuBarFolder (.dmg)](https://github.com/ilya000/MenuBarFolder/releases/latest)**
— signed with a Developer ID and notarized by Apple. macOS 13+.

Install: open the DMG and drag **MenuBarFolder** to Applications, then launch it
and pick a folder to pin. Also at [ctrl8.com/MenuBarFolder](http://ctrl8.com/MenuBarFolder).

## Build from source

You'll need macOS 13+ and a Swift toolchain (Xcode, or the command-line tools).

```bash
git clone https://github.com/ilya000/MenuBarFolder.git
cd MenuBarFolder
swift build -c release
.build/release/MenuBarFolder
```

A folder picker appears on first launch — pick a folder. Add more, change
sorting, or toggle *Start at Login* from **Settings… (Cmd-,)** in any icon's
menu.

Prefer to skip the picker? Seed folders straight from the command line:

```bash
.build/release/MenuBarFolder /Applications ~/Pictures ~/Downloads
```

They're remembered, so next time a plain `MenuBarFolder` brings them all back.

## The menu, briefly

```
<Folder name>
------------
...your files...          click to open · hover a subfolder to expand
------------
Open "<Folder>" in Finder
Settings...               Cmd-,
Quit                      Cmd-Q
```

Everything else — the folder list, sorting, grouping, Start at Login, and an
**About** tab — lives in the **Settings** window, so the menus stay tidy.

## Under the hood

- Folders are saved as bookmarks, so they keep working even if you move or
  rename them.
- *Start at Login* writes a small LaunchAgent
  (`~/Library/LaunchAgents/com.ctrl8.menubarfolder.plist`) pointing at the
  binary — no `.app` bundle required.
- Directory reads happen off the main thread, get cached, and are capped per
  level so the menu stays instant.
- Hidden dot-files are skipped. App bundles (`.app`, `.framework`, ...) are
  treated as openable items, not folders to browse into.

| File | Job |
|------|-----|
| `main.swift` | App delegate — owns the icons, the picker, CLI seeding. |
| `FolderPin.swift` | One menu-bar icon and menu per folder. |
| `FolderMenu.swift` | Background reading, sorting, lazy submenus. |
| `FolderStore.swift` | Persists the pinned-folder list. |
| `Prefs.swift` | Global sort and grouping settings. |
| `LoginItem.swift` | Start-at-Login via a LaunchAgent. |
| `StatusIcon.swift` | Draws the folder-with-two-letters icon. |
| `Settings.swift` | Settings window and About tab (SwiftUI). |
| `AppInfo.swift` | App identity shown in About. |

## Heritage

MenuBarFolder is the spiritual successor to **TrayMenu (1998)** — a Win95 /
Windows NT utility I wrote that put a fully customizable pop-up menu anywhere on
screen, including the system tray (next to the clock and keyboard switcher),
with directory submenus. Same idea, ~28 years later, native to the macOS menu
bar. The original still lives on my restored 1998 site:
[old.osipov.ru/proge.htm](https://old.osipov.ru/proge.htm).

## Status

Experimental, and proudly so. It works, it's small, and it scratches a real
itch. If it breaks, it breaks quietly — you can always just open Finder.

## License

MIT — see [LICENSE](LICENSE). Free and open source.
Copyright (c) 2026 Ilya Osipov (iLya Os).
