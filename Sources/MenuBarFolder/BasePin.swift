//
//  BasePin.swift
//  MenuBarFolder
//
//  Shared base for a single menu-bar icon. Concrete pins (a folder, a browser
//  bookmark source) own their content; the base owns the status item and the
//  common top "MenuBarFolder" submenu (program controls + add/close commands).
//

import AppKit

@MainActor
class BasePin: NSObject {

    let statusItem: NSStatusItem
    weak var app: AppDelegate?

    init(app: AppDelegate) {
        self.app = app
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
    }

    /// Remove this icon from the menu bar.
    func teardown() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    /// Drop any cached content so the next open re-reads. Overridden as needed.
    func clearCache() {}

    /// Per-instance "Display" items (sort / grouping) inserted as a section in
    /// the MenuBarFolder submenu. Empty by default; overridden by pins.
    func displaySectionItems() -> [NSMenuItem] { [] }

    /// Wording of the item that closes THIS menu-bar instance (a folder or a
    /// bookmarks source). "Menu instance" is the umbrella term for either —
    /// and makes clear nothing on disk (the folder, the browser's bookmarks)
    /// is touched.
    var closeTitle: String { "Close This Menu Instance" }

    /// The top "MenuBarFolder ▸" item: program controls and add/close commands.
    /// Lives at the top of every pin's menu so it never requires scrolling.
    func makeAppMenuItem() -> NSMenuItem {
        let appItem = NSMenuItem(title: "MenuBarFolder", action: nil, keyEquivalent: "")
        appItem.image = AppIcon.make(size: 36)
        appItem.image?.size = NSSize(width: 18, height: 18)

        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        settings.target = app
        menu.addItem(settings)

        // Per-instance display options live here as a section, so they don't add
        // a separate item to the main dropdown (which is mostly content).
        let display = displaySectionItems()
        if !display.isEmpty {
            menu.addItem(.separator())
            for item in display { menu.addItem(item) }
        }

        menu.addItem(.separator())

        let addFolder = NSMenuItem(title: "Open Another Folder…",
                                   action: #selector(openAnotherFolder), keyEquivalent: "n")
        addFolder.target = self
        menu.addItem(addFolder)

        let addBookmarks = NSMenuItem(title: "Open Browser Bookmarks…",
                                      action: #selector(addBookmarks), keyEquivalent: "")
        addBookmarks.target = self
        menu.addItem(addBookmarks)

        let close = NSMenuItem(title: closeTitle, action: #selector(closeThis), keyEquivalent: "w")
        close.target = self
        menu.addItem(close)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit MenuBarFolder",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = menu
        return appItem
    }

    // MARK: shared actions

    @objc func openAnotherFolder() { app?.addFolderViaPicker() }
    @objc func addBookmarks() { app?.addBookmarksViaChooser() }
    @objc func closeThis() { app?.closePin(self) }
}
