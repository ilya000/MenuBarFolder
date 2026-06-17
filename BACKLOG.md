# MenuBarFolder — Backlog

## Heritage / history — DONE (Ilya loves the lineage)
- [x] Mentioned in **About** and **README**: MenuBarFolder is the spiritual
  successor to **TrayMenu (1998)** — Ilya's Win95/Win NT pop-up-menu utility:
  a Start-button-like menu that could sit anywhere on screen (including the
  tray, next to the clock / keyboard switcher), fully customizable, with
  directory submenus. The surviving archive holds only `TRAYMENU.EXE`
  (463 KB, dated 1998) — no source, just the binary.
- [x] Link to the old-site publication: https://old.osipov.ru/proge.htm

## Ideas / later
- Right-click context menu on individual items (requires custom NSView-backed
  menu items + `NSMenu.popUp`; loses default item styling — weigh cost).
- Option-alternate secondary actions for bookmark items (e.g. Copy URL).
- Opera / Arc bookmark support (different profile layout: Opera stores its
  profile at the support-dir root; Arc uses `StorableSidebar.json`).
- Safari bookmarks (would need Full Disk Access — decided against for now).
