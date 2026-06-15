//
//  Settings.swift
//  MenuBarFolder
//
//  The Settings window: a SwiftUI form hosted in an NSWindow. Centralizes
//  everything that used to live in the status menus — the pinned-folder list,
//  sort order, folder grouping, and Start at Login.
//

import AppKit
import SwiftUI

// MARK: - Model

@MainActor
final class SettingsModel: ObservableObject {

    private weak var app: AppDelegate?

    @Published var sortMode: SortMode
    @Published var foldersOnTop: Bool
    @Published var startAtLogin: Bool
    @Published var folders: [URL]

    init(app: AppDelegate) {
        self.app = app
        self.sortMode = AppPrefs.sortMode
        self.foldersOnTop = AppPrefs.foldersOnTop
        self.startAtLogin = LoginItem.isEnabled
        self.folders = app.pinnedFolders
    }

    /// Re-pull state from the app/prefs when the window is re-shown.
    func reload() {
        sortMode = AppPrefs.sortMode
        foldersOnTop = AppPrefs.foldersOnTop
        startAtLogin = LoginItem.isEnabled
        folders = app?.pinnedFolders ?? []
    }

    func setSort(_ mode: SortMode) {
        sortMode = mode
        AppPrefs.sortMode = mode
        app?.invalidateAllCaches()
    }

    func setFoldersOnTop(_ on: Bool) {
        foldersOnTop = on
        AppPrefs.foldersOnTop = on
        app?.invalidateAllCaches()
    }

    func setStartAtLogin(_ on: Bool) {
        let ok = LoginItem.setEnabled(on)
        startAtLogin = ok ? on : LoginItem.isEnabled
    }

    func addFolder() {
        _ = app?.addFolderViaPicker()
        folders = app?.pinnedFolders ?? []
    }

    func remove(_ url: URL) {
        guard folders.count > 1 else { return }   // keep at least one icon
        app?.removeFolderURL(url)
        folders = app?.pinnedFolders ?? []
    }
}

// MARK: - View

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            GeneralSettingsTab(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 520)
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var model: SettingsModel
    @State private var selection: URL?

    var body: some View {
        Form {
            Section("Pinned folders") {
                List(selection: $selection) {
                    ForEach(model.folders, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(nsImage: Self.icon(for: url))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.displayName)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .tag(url)
                    }
                }
                .frame(minHeight: 140)

                HStack {
                    Button("Add Folder…") { model.addFolder() }
                    Button("Remove") {
                        if let sel = selection { model.remove(sel); selection = nil }
                    }
                    .disabled(selection == nil || model.folders.count <= 1)
                    Spacer()
                }
            }

            Section("Display") {
                Picker("Sort by", selection: Binding(
                    get: { model.sortMode },
                    set: { model.setSort($0) })) {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("Folders on top", isOn: Binding(
                    get: { model.foldersOnTop },
                    set: { model.setFoldersOnTop($0) }))
            }

            Section("General") {
                Toggle("Start at Login", isOn: Binding(
                    get: { model.startAtLogin },
                    set: { model.setStartAtLogin($0) }))
            }
        }
        .formStyle(.grouped)
    }

    private static func icon(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: StatusIcon.make(letters: "Fo"))
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 52)
                .foregroundStyle(.secondary)

            VStack(spacing: 3) {
                Text(AppInfo.name).font(.title2).bold()
                Text("Version \(AppInfo.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(AppInfo.summary)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Divider().padding(.vertical, 2)

            VStack(spacing: 6) {
                LabeledLink(label: "Home", title: AppInfo.homepage, url: AppInfo.homepage)
                LabeledLink(label: "Author", title: "\(AppInfo.author) · github.com/ilya000",
                            url: AppInfo.github)
                HStack(spacing: 6) {
                    Text("License").foregroundStyle(.secondary)
                    Text("\(AppInfo.license) — free and open source")
                }
                .font(.callout)
            }

            Spacer()

            Text("© 2026 \(AppInfo.author)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct LabeledLink: View {
    let label: String
    let title: String
    let url: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            if let u = URL(string: url) {
                Link(title, destination: u)
            } else {
                Text(title)
            }
        }
        .font(.callout)
    }
}

// MARK: - Window

@MainActor
final class SettingsWindowController {

    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var model: SettingsModel?

    func show(app: AppDelegate) {
        if window == nil {
            let model = SettingsModel(app: app)
            self.model = model
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let win = NSWindow(contentViewController: hosting)
            win.title = "MenuBarFolder Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            self.window = win
        } else {
            model?.reload()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
