//
//  FolderPin.swift
//  MenuBarFolder
//
//  One pinned folder = one menu-bar status item with its own dropdown.
//  Owns the status item, its menu, the lazy content delegate, and a cache
//  of the folder's last read so re-opening is instant while a fresh read
//  runs in the background.
//

import AppKit

@MainActor
final class FolderPin: NSObject, NSMenuDelegate {

    let url: URL
    private weak var app: AppDelegate?
    private let statusItem: NSStatusItem
    private let contentDelegate: FolderMenuDelegate
    private var listing: DirListing?

    init(url: URL, app: AppDelegate) {
        self.url = url
        self.app = app
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.contentDelegate = FolderMenuDelegate(url: url, owner: app)
        super.init()

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.image = StatusIcon.make(letters: String(url.displayName.prefix(2)))
            button.toolTip = "MenuBarFolder — \(url.displayName)"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Remove this icon from the menu bar.
    func teardown() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    /// Drop the cached contents so the next open re-reads with current prefs.
    func clearCache() {
        listing = nil
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshListing()
        layout(menu)
    }

    /// Read the folder off the main thread; re-render when it lands so even a
    /// huge pinned folder never freezes the menu.
    private func refreshListing() {
        let url = self.url
        let maxItems = contentDelegate.maxItems
        let options = AppPrefs.displayOptions
        Task { @MainActor in
            let fresh = await FolderMenuDelegate.readListing(url, maxItems: maxItems, options: options)
            self.listing = fresh
            if let menu = self.statusItem.menu { self.layout(menu) }
        }
    }

    private func layout(_ menu: NSMenu) {
        menu.removeAllItems()

        // Header — pinned folder name + icon.
        let header = NSMenuItem(title: url.displayName, action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.image = NSWorkspace.shared.icon(forFile: url.path)
        header.image?.size = NSSize(width: 16, height: 16)
        menu.addItem(header)
        menu.addItem(.separator())

        // Contents (cache → instant, else placeholder).
        if let listing {
            for item in contentDelegate.buildItems(from: listing) { menu.addItem(item) }
        } else {
            let loading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
            loading.isEnabled = false
            menu.addItem(loading)
        }

        menu.addItem(.separator())
        addItem(to: menu, title: "Open “\(url.displayName)” in Finder", action: #selector(openInFinder))

        // Everything else (add/change/remove folders, sort, grouping, login)
        // lives in the Settings window.
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(AppDelegate.openSettings),
                                  keyEquivalent: ",")
        settings.target = app
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MenuBarFolder",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    // MARK: actions (pin-specific)

    @objc private func openInFinder() { NSWorkspace.shared.open(url) }
}
