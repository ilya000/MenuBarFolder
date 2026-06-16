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

        // 1. App submenu at the very top — every program-level item lives here,
        //    so reaching Settings / Quit never means scrolling past the file list.
        menu.addItem(makeAppMenuItem())
        menu.addItem(.separator())

        // 2. The folder itself — name + icon, clicking it opens it in Finder.
        let folderItem = NSMenuItem(title: url.displayName,
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

    /// The top "MenuBarFolder ▸" item whose submenu holds the program controls.
    private func makeAppMenuItem() -> NSMenuItem {
        let appItem = NSMenuItem(title: "MenuBarFolder", action: nil, keyEquivalent: "")
        appItem.image = AppIcon.make(size: 36)
        appItem.image?.size = NSSize(width: 18, height: 18)

        let appMenu = NSMenu()

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(AppDelegate.openSettings),
                                  keyEquivalent: ",")
        settings.target = app
        appMenu.addItem(settings)

        appMenu.addItem(.separator())

        // Open one more menu-bar folder.
        let add = NSMenuItem(title: "Open Another Folder…",
                             action: #selector(openAnother), keyEquivalent: "n")
        add.target = self
        appMenu.addItem(add)

        // Close JUST this icon (program keeps running for the others).
        let close = NSMenuItem(title: "Close This Folder",
                               action: #selector(closeThis), keyEquivalent: "w")
        close.target = self
        appMenu.addItem(close)

        appMenu.addItem(.separator())

        // Quit the whole program (all icons).
        appMenu.addItem(NSMenuItem(title: "Quit MenuBarFolder",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appItem.submenu = appMenu
        return appItem
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    // MARK: actions (pin-specific)

    @objc private func openInFinder() { NSWorkspace.shared.open(url) }
    @objc private func openAnother()  { app?.addFolderViaPicker() }
    @objc private func closeThis()    { app?.closePin(self) }
}
