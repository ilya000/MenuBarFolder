//
//  FolderPin.swift
//  MenuBarFolder
//
//  One pinned folder = one menu-bar status item with its own dropdown and its
//  OWN display settings (sort order + folder grouping), persisted per folder.
//

import AppKit

@MainActor
final class FolderPin: BasePin, NSMenuDelegate {

    let url: URL
    private let id: String                       // persistence key (folder path)
    private let contentDelegate: FolderMenuDelegate
    private var options: DisplayOptions
    private var listing: DirListing?

    init(url: URL, app: AppDelegate) {
        self.url = url
        self.id = url.standardizedFileURL.path
        self.contentDelegate = FolderMenuDelegate(url: url, owner: app)
        self.options = InstancePrefs.options(for: id)
        super.init(app: app)
        contentDelegate.options = options

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.image = StatusIcon.make(letters: String(url.displayName.prefix(2)))
            button.toolTip = "MenuBarFolder — \(url.displayName)"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Drop the cached contents so the next open re-reads with current options.
    override func clearCache() { listing = nil }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshListing()
        layout(menu)
    }

    private func refreshListing() {
        let url = self.url
        let maxItems = contentDelegate.maxItems
        let options = self.options
        Task { @MainActor in
            let fresh = await FolderMenuDelegate.readListing(url, maxItems: maxItems, options: options)
            self.listing = fresh
            if let menu = self.statusItem.menu { self.layout(menu) }
        }
    }

    private func layout(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. App submenu (program controls).
        menu.addItem(makeAppMenuItem())
        menu.addItem(.separator())

        // 2. The folder itself (click → Finder) + its own Display settings.
        let folderItem = NSMenuItem(title: url.displayName.ellipsizedMenuTitle(),
                                    action: #selector(openInFinder), keyEquivalent: "")
        folderItem.target = self
        folderItem.image = NSWorkspace.shared.icon(forFile: url.path)
        folderItem.image?.size = NSSize(width: 16, height: 16)
        folderItem.toolTip = "Open “\(url.displayName)” in Finder"
        menu.addItem(folderItem)
        menu.addItem(.separator())

        // 3. Folder contents (cache → instant, else placeholder).
        if let listing {
            for item in contentDelegate.buildItems(from: listing) { menu.addItem(item) }
        } else {
            let loading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
            loading.isEnabled = false
            menu.addItem(loading)
        }
    }

    /// This folder's own sort + grouping, shown as a section in the
    /// MenuBarFolder submenu.
    override func displaySectionItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let sortHeader = NSMenuItem(title: "Sort by", action: nil, keyEquivalent: "")
        sortHeader.isEnabled = false
        items.append(sortHeader)
        for mode in SortMode.allCases {
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

    // MARK: actions

    @objc private func openInFinder() { NSWorkspace.shared.open(url) }

    @objc private func setSort(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = SortMode(rawValue: raw) else { return }
        options.sort = mode
        persistOptions()
    }

    @objc private func toggleFoldersOnTop() {
        options.foldersOnTop.toggle()
        persistOptions()
    }

    private func persistOptions() {
        InstancePrefs.set(options, for: id)
        contentDelegate.options = options
        listing = nil   // re-read with the new order on next open
    }
}
