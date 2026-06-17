//
//  BookmarksPin.swift
//  MenuBarFolder
//
//  One pinned browser-bookmark source = one menu-bar icon (the browser's own
//  icon) showing that profile's bookmark tree. Folders become submenus, links
//  open in the SOURCE browser, and each link shows its favicon.
//

import AppKit

@MainActor
final class BookmarksPin: BasePin, NSMenuDelegate {

    let source: BookmarkSource
    let profileName: String
    private let browser: Browser
    private var options: BookmarkDisplayOptions

    private var items: [BookmarkItem]?
    private var iconData: [String: Data] = [:]

    init?(source: BookmarkSource, app: AppDelegate) {
        guard let browser = Browser.by(id: source.browserID) else { return nil }
        self.source = source
        self.browser = browser
        let match = browser.profiles().profiles.first { $0.dir == source.profileDir }
        self.profileName = match?.name ?? source.profileDir
        self.options = InstancePrefs.bookmarkOptions(for: source.id)
        super.init(app: app)

        applyIcon(profileLetters: nil)

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Set the menu-bar icon. When several profiles of the SAME browser are
    /// pinned, `profileLetters` (two letters of the profile name) is shown and
    /// the browser badge shifts right, so they're distinguishable; otherwise
    /// just the folder + browser badge.
    func applyIcon(profileLetters: String?) {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        if let icon = browser.appIcon {
            button.image = StatusIcon.make(browserIcon: icon, profileLetters: profileLetters)
        } else {
            button.image = StatusIcon.make(letters: String(profileName.prefix(2)))
        }
        button.toolTip = "\(browser.name) — \(profileName) bookmarks"
    }

    override func clearCache() { items = nil; iconData = [:] }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        layout(menu)
    }

    /// Parse the bookmarks file + read favicons off the main thread (raw, all
    /// Sendable), then rebuild the menu on the main actor.
    private func refresh() {
        let support = browser.supportURL
        let dir = source.profileDir
        Task { @MainActor in
            let (items, icons) = await Self.load(support: support, profileDir: dir)
            self.items = items
            self.iconData = icons
            if let menu = self.statusItem.menu { self.layout(menu) }
        }
    }

    nonisolated private static func load(support: URL, profileDir: String)
        async -> ([BookmarkItem], [String: Data]) {
        let profile = support.appendingPathComponent(profileDir)
        let items = BookmarkParser.parse(profilePath: profile)
        let icons = Favicons.data(profilePath: profile, for: BookmarkParser.allURLs(items))
        return (items, icons)
    }

    // MARK: rendering

    private func layout(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. App submenu (program controls) at the very top.
        menu.addItem(makeAppMenuItem())
        menu.addItem(.separator())

        // 2. Header: browser + profile.
        let header = NSMenuItem(title: "\(browser.name) · \(profileName)".ellipsizedMenuTitle(),
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        if let icon = browser.appIcon { icon.size = NSSize(width: 16, height: 16); header.image = icon }
        menu.addItem(header)
        menu.addItem(.separator())

        // 3. Bookmark tree (ordered per this instance's options).
        guard let items else {
            let loading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
            loading.isEnabled = false
            menu.addItem(loading)
            return
        }
        if items.isEmpty {
            let empty = NSMenuItem(title: "(no bookmarks)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        populate(menu, with: BookmarkSort.apply(items, options))
    }

    /// This instance's own sort + grouping, shown as a section in the
    /// MenuBarFolder submenu.
    override func displaySectionItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let sortHeader = NSMenuItem(title: "Sort by", action: nil, keyEquivalent: "")
        sortHeader.isEnabled = false
        items.append(sortHeader)
        for mode in BookmarkSortMode.allCases {
            let mi = NSMenuItem(title: mode.title, action: #selector(setSort(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = mode.rawValue
            mi.state = (mode == options.sort) ? .on : .off
            items.append(mi)
        }
        let fot = NSMenuItem(title: "Folders on top",
                             action: #selector(toggleFoldersOnTop), keyEquivalent: "")
        fot.target = self
        fot.state = options.foldersOnTop ? .on : .off
        items.append(fot)
        return items
    }

    @objc private func setSort(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = BookmarkSortMode(rawValue: raw) else { return }
        options.sort = mode
        InstancePrefs.setBookmark(options, for: source.id)
    }

    @objc private func toggleFoldersOnTop() {
        options.foldersOnTop.toggle()
        InstancePrefs.setBookmark(options, for: source.id)
    }

    /// Add `items` to `menu`. Folders become submenus; links get a primary
    /// "open in the source browser" item plus an Option-alternate "Copy Link".
    private func populate(_ menu: NSMenu, with items: [BookmarkItem]) {
        for item in items {
            let full = item.displayTitle
            if item.isFolder {
                let mi = NSMenuItem(title: full.ellipsizedMenuTitle(), action: nil, keyEquivalent: "")
                mi.image = Self.folderIcon
                if full.count > String.menuTitleLimit { mi.toolTip = full }
                let sub = NSMenu()
                if item.children.isEmpty {
                    let empty = NSMenuItem(title: "(empty)", action: nil, keyEquivalent: "")
                    empty.isEnabled = false
                    sub.addItem(empty)
                } else {
                    populate(sub, with: item.children)
                }
                mi.submenu = sub
                menu.addItem(mi)
            } else {
                let mi = NSMenuItem(title: full.ellipsizedMenuTitle(),
                                    action: #selector(openBookmark(_:)), keyEquivalent: "")
                mi.target = self
                mi.representedObject = item.url
                mi.image = icon(for: item.url) ?? Self.linkIcon
                mi.toolTip = [full, item.url].compactMap { $0 }.joined(separator: "\n")
                mi.keyEquivalentModifierMask = []   // so the Option-alternate groups correctly
                menu.addItem(mi)

                let alt = NSMenuItem(title: "Copy Link",
                                     action: #selector(copyBookmarkURL(_:)), keyEquivalent: "")
                alt.target = self
                alt.representedObject = item.url
                alt.image = icon(for: item.url) ?? Self.linkIcon
                alt.isAlternate = true
                alt.keyEquivalentModifierMask = [.option]
                menu.addItem(alt)
            }
        }
    }

    /// Build (and cache) an NSImage for a bookmark URL's favicon PNG.
    private var imageCache: [String: NSImage] = [:]
    private func icon(for url: String?) -> NSImage? {
        guard let url, let data = iconData[url] else { return nil }
        if let cached = imageCache[url] { return cached }
        guard let img = NSImage(data: data) else { return nil }
        img.size = NSSize(width: 16, height: 16)
        imageCache[url] = img
        return img
    }

    @objc private func openBookmark(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let url = URL(string: s) else { return }
        if let appURL = browser.appURL {
            NSWorkspace.shared.open([url], withApplicationAt: appURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Option-alternate of a bookmark: copy its URL to the clipboard.
    @objc private func copyBookmarkURL(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private static let folderIcon: NSImage? = {
        let i = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        i?.size = NSSize(width: 15, height: 15); i?.isTemplate = true
        return i
    }()
    private static let linkIcon: NSImage? = {
        let i = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        i?.size = NSSize(width: 15, height: 15); i?.isTemplate = true
        return i
    }()
}
