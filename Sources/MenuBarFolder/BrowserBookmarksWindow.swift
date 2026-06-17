//
//  BrowserBookmarksWindow.swift
//  MenuBarFolder
//
//  The "Add Browser Bookmarks" chooser: pick an installed browser and one of
//  its profiles (the last-used profile is preselected), then add it as a new
//  menu-bar icon.
//

import AppKit
import SwiftUI

@MainActor
final class BrowserBookmarksModel: ObservableObject {

    private weak var app: AppDelegate?
    var onClose: () -> Void = {}

    let browsers: [Browser]
    @Published var selectedBrowserID: String { didSet { reloadProfiles() } }
    @Published var profiles: [BrowserProfile] = []
    @Published var selectedProfileDir: String = ""

    init(app: AppDelegate) {
        self.app = app
        // Every installed browser that actually has at least one profile.
        self.browsers = Browser.installed.filter { !$0.profiles().profiles.isEmpty }
        self.selectedBrowserID = browsers.first?.id ?? ""
        reloadProfiles()
    }

    var canAdd: Bool { !selectedBrowserID.isEmpty && !selectedProfileDir.isEmpty }

    func reloadProfiles() {
        guard let browser = Browser.by(id: selectedBrowserID) else { profiles = []; selectedProfileDir = ""; return }
        let result = browser.profiles()
        profiles = result.profiles
        selectedProfileDir = result.lastUsed ?? profiles.first?.dir ?? ""
    }

    func add() {
        guard canAdd else { return }
        app?.addBookmarkSource(BookmarkSource(browserID: selectedBrowserID, profileDir: selectedProfileDir))
        onClose()
    }

    func cancel() { onClose() }
}

struct BrowserBookmarksView: View {
    @ObservedObject var model: BrowserBookmarksModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Browser Bookmarks").font(.title3).bold()

            if model.browsers.isEmpty {
                Text("No supported browser with bookmarks was found. MenuBarFolder reads "
                     + "bookmarks from Chrome, Brave, Edge, and Vivaldi.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Browser").gridColumnAlignment(.trailing)
                        Picker("", selection: Binding(
                            get: { model.selectedBrowserID },
                            set: { model.selectedBrowserID = $0 })) {
                            ForEach(model.browsers) { Text($0.name).tag($0.id) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    GridRow {
                        Text("Profile").gridColumnAlignment(.trailing)
                        Picker("", selection: Binding(
                            get: { model.selectedProfileDir },
                            set: { model.selectedProfileDir = $0 })) {
                            ForEach(model.profiles) { Text($0.name).tag($0.dir) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
                Text("Its bookmarks appear as a new menu-bar icon. Clicking a bookmark "
                     + "opens it in \(Browser.by(id: model.selectedBrowserID)?.name ?? "the browser").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction)
                Button("Add") { model.add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canAdd)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

@MainActor
final class BrowserBookmarksWindowController {

    static let shared = BrowserBookmarksWindowController()
    private var window: NSWindow?

    func show(app: AppDelegate) {
        let model = BrowserBookmarksModel(app: app)
        model.onClose = { [weak self] in self?.window?.close() }

        let hosting = NSHostingController(rootView: BrowserBookmarksView(model: model))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Add Browser Bookmarks"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false

        window?.close()
        window = win
        NSApp.activate(ignoringOtherApps: true)
        win.center()
        win.makeKeyAndOrderFront(nil)
    }
}
