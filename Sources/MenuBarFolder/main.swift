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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = FolderStore()
    private var pins: [FolderPin] = []

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPrefs.registerDefaults()

        // Folder paths on the command line are added to the persistent set
        // (deduped), so `MenuBarFolder ~/A ~/B` seeds icons on first launch and
        // a later bare launch restores them.
        for url in Self.foldersFromArguments() {
            store.add(url)
        }

        // Nothing pinned yet → ask for a first folder so the app isn't an
        // invisible process with no icons.
        if store.folders.isEmpty {
            if let url = runFolderPicker() {
                store.add(url)
            } else {
                NSApp.terminate(nil)
                return
            }
        }

        for url in store.folders {
            addPin(for: url)
        }
    }

    // MARK: pin management

    private func addPin(for url: URL) {
        pins.append(FolderPin(url: url, app: self))
    }

    /// Ask for a folder and add it as a new menu-bar icon (deduped).
    /// Returns the added URL, or nil if cancelled / already pinned.
    @discardableResult
    func addFolderViaPicker() -> URL? {
        guard let url = runFolderPicker() else { return nil }
        guard store.add(url) else { return nil }   // already pinned → no-op
        addPin(for: url)
        return url.standardizedFileURL
    }

    private func tearDown(_ pin: FolderPin) {
        pin.teardown()
        pins.removeAll { $0 === pin }
    }

    // MARK: shared actions

    /// Open a file/folder entry in its default application (Finder-double-click
    /// semantics). Target for every content item built by FolderMenuDelegate.
    @objc func openItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openSettings() {
        SettingsWindowController.shared.show(app: self)
    }

    // MARK: settings-window support

    /// The pinned folders, in order (source of truth = the store).
    var pinnedFolders: [URL] { store.folders }

    /// Remove a pinned folder by URL (settings window). Unlike the menu's
    /// "Remove this folder", this never force-quits — the settings UI keeps at
    /// least one folder by disabling its Remove button.
    func removeFolderURL(_ url: URL) {
        guard let pin = pins.first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        store.remove(pin.url)
        tearDown(pin)
    }

    /// Close ONE menu-bar icon (the folder is unpinned, but the program keeps
    /// running for the other icons). Distinct from Quit. If it was the last
    /// icon there's nothing left to show, so the app quits.
    func closePin(_ pin: FolderPin) {
        store.remove(pin.url)
        tearDown(pin)
        if pins.isEmpty { NSApp.terminate(nil) }
    }

    /// Drop every icon's cached listing so the next open re-reads with the
    /// updated sort / grouping preference.
    func invalidateAllCaches() {
        for pin in pins { pin.clearCache() }
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
