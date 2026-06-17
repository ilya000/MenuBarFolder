//
//  FolderMenu.swift
//  MenuBarFolder
//
//  Lazily turns a directory into an NSMenu. Each subfolder becomes a
//  submenu whose contents are built only when the user actually hovers
//  it, so a deeply-nested pinned folder is never walked in full up front.
//
//  Big folders — at ANY level — are handled three ways:
//    1. Directory reading + sorting happens on a background queue, so
//       hovering a huge subfolder never freezes the menu. A "Loading…"
//       placeholder shows until the read finishes (or the cached result
//       from a previous open shows instantly, then refreshes).
//    2. Each entry's attributes are read exactly once, not re-statted
//       inside the sort comparator.
//    3. Only the first `maxItems` rows are rendered; the rest collapse
//       into a single "open in Finder" line.
//
//  Ordering and folder grouping follow the global AppPrefs.
//

import AppKit

/// One renderable entry — a file or a (browsable) folder.
struct DirEntry: Sendable {
    let url: URL
    let isDir: Bool
}

/// Plain, Sendable snapshot of a directory's renderable contents, produced
/// off the main thread and handed back for icon/menu construction on main.
struct DirListing: Sendable {
    var entries: [DirEntry]   // already ordered & capped
    var separatorAfter: Int   // insert a separator before this index (0 = none)
    var hidden: Int
    var failed: Bool
}

@MainActor
final class FolderMenuDelegate: NSObject, NSMenuDelegate {

    let url: URL
    private weak var owner: AppDelegate?

    /// Max rows rendered per menu level. Beyond this the first ones are shown
    /// and the remainder collapse into a "+N more" line.
    let maxItems = 250

    /// NSMenu holds its delegate weakly, so every child-folder delegate we
    /// create must be retained somewhere or it would vanish before the
    /// submenu opens. Rebuilt on each render.
    private var childDelegates: [FolderMenuDelegate] = []

    /// Last successful listing, shown instantly on re-open while a fresh
    /// read runs in the background.
    private var cache: DirListing?

    /// Display options inherited from the owning folder pin (so a subfolder
    /// sorts the same way as its top-level folder).
    var options: DisplayOptions = .default

    init(url: URL, owner: AppDelegate?) {
        self.url = url
        self.owner = owner
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }

    /// Show whatever we have immediately (cache, else a placeholder), then
    /// read the directory off-main and re-render when it lands.
    func populate(_ menu: NSMenu) {
        if let cache {
            render(cache, into: menu)
        } else {
            menu.removeAllItems()
            childDelegates.removeAll()
            menu.addItem(disabledItem("Loading…"))
        }

        let url = self.url
        let maxItems = self.maxItems
        let options = self.options
        // `readListing` is nonisolated+async, so the filesystem work runs off
        // the main actor; only the result re-enters main to render. `menu`
        // never leaves the main actor, so there's no Sendable hazard.
        Task { @MainActor in
            let listing = await Self.readListing(url, maxItems: maxItems, options: options)
            self.cache = listing
            self.render(listing, into: menu)
        }
    }

    // MARK: - background read (no main-actor state touched)

    nonisolated static func readListing(_ url: URL,
                                        maxItems: Int,
                                        options: DisplayOptions) async -> DirListing {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .localizedNameKey,
                                      .addedToDirectoryDateKey, .creationDateKey,
                                      .contentModificationDateKey, .fileSizeKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return DirListing(entries: [], separatorAfter: 0, hidden: 0, failed: true)
        }

        // Read each entry's attributes ONCE (values were prefetched above),
        // instead of re-reading them O(n log n) times inside the comparator.
        struct Meta {
            let url: URL
            let name: String
            let isDir: Bool
            let added: Date?
            let modified: Date?
            let size: Int
        }
        var metas: [Meta] = []
        metas.reserveCapacity(entries.count)
        for entry in entries {
            let v = try? entry.resourceValues(forKeys: Set(keys))
            let isPkg = v?.isPackage ?? false              // .app / .framework → treat as a file
            let isDir = (v?.isDirectory ?? false) && !isPkg
            metas.append(Meta(
                url: entry,
                name: v?.localizedName ?? entry.lastPathComponent,
                isDir: isDir,
                added: v?.addedToDirectoryDate ?? v?.creationDate,
                modified: v?.contentModificationDate,
                size: v?.fileSize ?? 0
            ))
        }

        func nameAsc(_ a: Meta, _ b: Meta) -> Bool {
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        func dateDesc(_ da: Date?, _ db: Date?, _ a: Meta, _ b: Meta) -> Bool {
            if let da, let db, da != db { return da > db }
            if da != nil, db == nil { return true }
            if da == nil, db != nil { return false }
            return nameAsc(a, b)
        }
        func less(_ a: Meta, _ b: Meta) -> Bool {
            switch options.sort {
            case .name:         return nameAsc(a, b)
            case .dateAdded:    return dateDesc(a.added, b.added, a, b)
            case .dateModified: return dateDesc(a.modified, b.modified, a, b)
            case .size:         return a.size != b.size ? a.size > b.size : nameAsc(a, b)
            }
        }

        if options.foldersOnTop {
            let folders = metas.filter { $0.isDir }.sorted(by: less)
            let files   = metas.filter { !$0.isDir }.sorted(by: less)
            var shownFolders = folders
            var shownFiles = files
            if shownFolders.count >= maxItems {
                shownFolders = Array(shownFolders.prefix(maxItems))
                shownFiles = []
            } else {
                shownFiles = Array(files.prefix(maxItems - shownFolders.count))
            }
            let entries = (shownFolders + shownFiles).map { DirEntry(url: $0.url, isDir: $0.isDir) }
            let sep = (!shownFolders.isEmpty && !shownFiles.isEmpty) ? shownFolders.count : 0
            let hidden = (folders.count - shownFolders.count) + (files.count - shownFiles.count)
            return DirListing(entries: entries, separatorAfter: sep, hidden: hidden, failed: false)
        } else {
            let sorted = metas.sorted(by: less)
            let shown = Array(sorted.prefix(maxItems))
            let entries = shown.map { DirEntry(url: $0.url, isDir: $0.isDir) }
            return DirListing(entries: entries, separatorAfter: 0,
                              hidden: sorted.count - shown.count, failed: false)
        }
    }

    // MARK: - main-thread rendering

    private func render(_ listing: DirListing, into menu: NSMenu) {
        menu.removeAllItems()
        for item in buildItems(from: listing) {
            menu.addItem(item)
        }
    }

    /// Turn a listing into ready-to-insert menu items (folders as lazy
    /// submenus). Resets and repopulates `childDelegates`, so the caller must
    /// keep THIS delegate alive for the items to keep working. Used both for
    /// submenus and for a status menu (items inserted by FolderPin).
    func buildItems(from listing: DirListing) -> [NSMenuItem] {
        childDelegates.removeAll()

        if listing.failed { return [disabledItem("(can’t read folder)")] }
        if listing.entries.isEmpty { return [disabledItem("(empty)")] }

        var items: [NSMenuItem] = []

        for (i, entry) in listing.entries.enumerated() {
            if listing.separatorAfter > 0, i == listing.separatorAfter {
                items.append(.separator())
            }
            let item = makeItem(for: entry.url)
            if entry.isDir {
                // Submenu, populated lazily by its own delegate.
                let submenu = NSMenu(title: entry.url.displayName)
                let delegate = FolderMenuDelegate(url: entry.url, owner: owner)
                delegate.options = options   // subfolders inherit this folder's sort/grouping
                submenu.delegate = delegate
                childDelegates.append(delegate)
                item.submenu = submenu
                items.append(item)
            } else {
                items.append(item)
                // Hold Option to reveal the file in Finder instead of opening.
                items.append(makeRevealAlternate(for: entry.url))
            }
        }

        if listing.hidden > 0 {
            items.append(.separator())
            let more = NSMenuItem(title: "+\(listing.hidden) more — open in Finder",
                                  action: #selector(AppDelegate.openItem(_:)), keyEquivalent: "")
            more.target = owner
            more.representedObject = url   // opening the folder shows the rest in Finder
            items.append(more)
        }

        return items
    }

    // MARK: - helpers

    private func makeItem(for fileURL: URL) -> NSMenuItem {
        let name = fileURL.displayName
        let item = NSMenuItem(title: name.ellipsizedMenuTitle(),
                              action: #selector(AppDelegate.openItem(_:)),
                              keyEquivalent: "")
        item.target = owner
        item.representedObject = fileURL
        item.image = Self.icon(for: fileURL)
        item.keyEquivalentModifierMask = []   // so the Option-alternate groups correctly
        if name.count > String.menuTitleLimit { item.toolTip = name }
        return item
    }

    /// Hidden sibling shown while Option is held: "Reveal in Finder".
    private func makeRevealAlternate(for fileURL: URL) -> NSMenuItem {
        let item = NSMenuItem(title: "Reveal in Finder",
                              action: #selector(AppDelegate.revealItem(_:)), keyEquivalent: "")
        item.target = owner
        item.representedObject = fileURL
        item.image = Self.icon(for: fileURL)
        item.isAlternate = true
        item.keyEquivalentModifierMask = [.option]
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func icon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}

extension String {
    /// Max characters shown for a menu title before truncation.
    static let menuTitleLimit = 30

    /// Trim to `menuTitleLimit` characters with a single ellipsis, so one long
    /// file/bookmark name can't blow the menu up to full-screen width.
    func ellipsizedMenuTitle() -> String {
        guard count > Self.menuTitleLimit else { return self }
        return prefix(Self.menuTitleLimit).trimmingCharacters(in: .whitespaces) + "…"
    }
}

extension URL {
    /// The Finder-localized display name (localized system folder names,
    /// extension hiding), falling back to the last path component.
    var displayName: String {
        if let v = try? resourceValues(forKeys: [.localizedNameKey]),
           let name = v.localizedName {
            return name
        }
        return lastPathComponent
    }
}
