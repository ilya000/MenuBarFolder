//
//  main.swift
//  MenuBarFolder
//
//  A tiny menu-bar utility: pin one or more favourite folders to the menu
//  bar and browse each from its own dropdown. Click a file to open it in its
//  default app; subfolders open as nested submenus. Each pinned folder is a
//  separate menu-bar icon labelled with its first two letters, and the whole
//  set is remembered across relaunches.
//

import AppKit

extension Notification.Name {
    /// Posted whenever the set of pinned folders/bookmarks changes, so an open
    /// Settings window can refresh its lists live.
    static let mbfPinsChanged = Notification.Name("MBFPinsChanged")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = FolderStore()
    private let bookmarkStore = BookmarkStore()
    private var pins: [BasePin] = []

    /// Shown only when nothing is pinned: an empty menu offering the setup
    /// actions, so the app is never an invisible, unreachable process.
    private var setupItem: NSStatusItem?

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Folder paths on the command line are added to the persistent set
        // (deduped), so `MenuBarFolder ~/A ~/B` seeds icons on first launch and
        // a later bare launch restores them.
        for url in Self.foldersFromArguments() {
            store.add(url)
        }

        for url in store.folders { addFolderPin(url) }
        for src in bookmarkStore.sources { addBookmarkPin(src) }

        if pins.isEmpty { showSetupItem() }
    }

    // MARK: pin management

    private func addFolderPin(_ url: URL) {
        removeSetupItem()
        pins.append(FolderPin(url: url, app: self))
        notifyPinsChanged()
    }

    private func addBookmarkPin(_ source: BookmarkSource) {
        guard let pin = BookmarksPin(source: source, app: self) else { return }
        removeSetupItem()
        pins.append(pin)
        updateBookmarkIcons()
        notifyPinsChanged()
    }

    /// Show profile letters on a bookmark icon only when more than one profile
    /// of the same browser is pinned (otherwise the browser badge is enough).
    /// Letters are chosen to be DISTINCT within each browser group, so
    /// "ilya@ctrl8" / "ilya@wowcube" become "ct" / "wo" rather than both "il".
    private func updateBookmarkIcons() {
        let bookmarkPins = pins.compactMap { $0 as? BookmarksPin }
        var groups: [String: [BookmarksPin]] = [:]
        for pin in bookmarkPins { groups[pin.source.browserID, default: []].append(pin) }

        for (_, group) in groups {
            if group.count <= 1 {
                group.first?.applyIcon(profileLetters: nil)
            } else {
                let labels = ProfileLabel.distinct(group.map(\.profileName))
                for (pin, label) in zip(group, labels) { pin.applyIcon(profileLetters: label) }
            }
        }
    }

    /// Ask for a folder and add it as a new menu-bar icon (deduped).
    @discardableResult
    func addFolderViaPicker() -> URL? {
        guard let url = runFolderPicker() else { return nil }
        guard store.add(url) else { return nil }   // already pinned → no-op
        addFolderPin(url)
        return url.standardizedFileURL
    }

    /// Open the browser-bookmarks chooser to add a new bookmarks icon.
    func addBookmarksViaChooser() {
        BrowserBookmarksWindowController.shared.show(app: self)
    }

    /// Add a bookmark source chosen in the chooser (deduped).
    func addBookmarkSource(_ source: BookmarkSource) {
        guard bookmarkStore.add(source) else { return }
        addBookmarkPin(source)
    }

    private func tearDown(_ pin: BasePin) {
        pin.teardown()
        pins.removeAll { $0 === pin }
        updateBookmarkIcons()   // a removal may drop a browser back to one profile
        notifyPinsChanged()
    }

    private func notifyPinsChanged() {
        NotificationCenter.default.post(name: .mbfPinsChanged, object: nil)
    }

    // MARK: shared actions

    /// Open a file/folder entry in its default application (Finder-double-click
    /// semantics). Target for every content item built by FolderMenuDelegate.
    @objc func openItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Option-alternate of a file item: reveal it in Finder instead of opening.
    @objc func revealItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func openSettings() {
        SettingsWindowController.shared.show(app: self)
    }

    @objc private func setupAddFolder() { addFolderViaPicker() }
    @objc private func setupAddBookmarks() { addBookmarksViaChooser() }

    // MARK: settings-window support

    /// The pinned folders, in order (source of truth = the store).
    var pinnedFolders: [URL] { store.folders }

    /// The pinned bookmark sources.
    var bookmarkSources: [BookmarkSource] { bookmarkStore.sources }

    /// Remove a pinned folder by URL (settings window). Never force-quits;
    /// if it leaves nothing pinned, the setup menu reappears.
    func removeFolderURL(_ url: URL) {
        guard let pin = pins.compactMap({ $0 as? FolderPin })
            .first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        store.remove(pin.url)
        tearDown(pin)
        if pins.isEmpty { showSetupItem() }
    }

    func removeBookmarkSource(_ source: BookmarkSource) {
        bookmarkStore.remove(source)
        if let pin = pins.compactMap({ $0 as? BookmarksPin }).first(where: { $0.source == source }) {
            tearDown(pin)
        }
        if pins.isEmpty { showSetupItem() }
    }

    /// Close ONE menu-bar icon (folder or bookmarks). The program keeps running
    /// for the others; if it was the last, the setup menu reappears.
    func closePin(_ pin: BasePin) {
        if let f = pin as? FolderPin { store.remove(f.url) }
        else if let b = pin as? BookmarksPin { bookmarkStore.remove(b.source) }
        tearDown(pin)
        if pins.isEmpty { showSetupItem() }
    }

    // MARK: empty-state setup item

    private func showSetupItem() {
        guard setupItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageOnly
            let icon = AppIcon.make(size: 36)
            icon.size = NSSize(width: 20, height: 18)
            button.image = icon
            button.toolTip = "MenuBarFolder — nothing pinned yet"
        }
        let menu = NSMenu()
        let header = NSMenuItem(title: "Nothing pinned yet", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        let addFolder = NSMenuItem(title: "Pin a Folder…", action: #selector(setupAddFolder), keyEquivalent: "")
        addFolder.target = self
        menu.addItem(addFolder)
        let addBookmarks = NSMenuItem(title: "Open Browser Bookmarks…", action: #selector(setupAddBookmarks), keyEquivalent: "")
        addBookmarks.target = self
        menu.addItem(addBookmarks)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MenuBarFolder",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        setupItem = item
    }

    private func removeSetupItem() {
        if let item = setupItem {
            NSStatusBar.system.removeStatusItem(item)
            setupItem = nil
        }
    }

    // MARK: helpers

    private func runFolderPicker() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Pin Folder"
        panel.message = "Choose a folder to pin to the menu bar."
        NSApp.activate(ignoringOtherApps: true)   // bring the panel to the front
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Non-flag command-line arguments that are readable directories
    /// (tilde- and relative-path aware).
    private static func foldersFromArguments() -> [URL] {
        CommandLine.arguments.dropFirst()
            .filter { !$0.hasPrefix("-") }
            .compactMap { arg in
                let expanded = (arg as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded).standardizedFileURL
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                      isDir.boolValue else {
                    NSLog("MenuBarFolder: argument is not a folder: \(arg)")
                    return nil
                }
                return url
            }
    }
}

// MARK: - main

MainActor.assumeIsolated {
    // Build-time helper: `MenuBarFolder --export-icon <path.png>` renders the
    // app icon to a PNG and exits, so the packaging script can derive the
    // .icns from the same drawing code (single source of truth). No GUI.
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--export-icon"), i + 1 < args.count {
        let out = URL(fileURLWithPath: args[i + 1])
        let img = AppIcon.make(size: 1024)
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: out)
            exit(0)
        }
        exit(1)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
    app.run()
}
