//
//  Browser.swift
//  MenuBarFolder
//
//  Detects installed Chromium-family browsers and their profiles. Bookmarks
//  and favicons live under each profile in ~/Library/Application Support; no
//  special permissions are needed for these locations (unlike Safari, which
//  would require Full Disk Access and is intentionally not supported).
//

import AppKit

/// A supported Chromium-family browser.
struct Browser: Identifiable, Hashable {
    let id: String          // stable key, e.g. "chrome"
    let name: String        // display name
    let bundleID: String    // for opening URLs in this browser
    let supportDir: String  // relative to ~/Library/Application Support

    /// Every browser we know how to read (all share the Chromium layout).
    static let all: [Browser] = [
        Browser(id: "chrome",  name: "Google Chrome", bundleID: "com.google.Chrome",     supportDir: "Google/Chrome"),
        Browser(id: "brave",   name: "Brave",         bundleID: "com.brave.Browser",      supportDir: "BraveSoftware/Brave-Browser"),
        Browser(id: "edge",    name: "Microsoft Edge", bundleID: "com.microsoft.edgemac", supportDir: "Microsoft Edge"),
        Browser(id: "vivaldi", name: "Vivaldi",       bundleID: "com.vivaldi.Vivaldi",    supportDir: "Vivaldi"),
    ]

    static func by(id: String) -> Browser? { all.first { $0.id == id } }

    /// Absolute path to this browser's Application Support directory.
    var supportURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(supportDir)")
    }

    /// Installed iff its support directory exists.
    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: supportURL.path)
    }

    static var installed: [Browser] { all.filter(\.isInstalled) }

    /// Location of the installed app, used to open URLs in this browser.
    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// The app icon (for the menu-bar status item), if the app is present.
    var appIcon: NSImage? {
        guard let app = appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: app.path)
    }
}

/// One profile inside a browser.
struct BrowserProfile: Identifiable, Hashable {
    let dir: String     // on-disk directory, e.g. "Default" / "Profile 4"
    let name: String    // human label from Local State
    var id: String { dir }
}

extension Browser {

    /// Profiles for this browser, with the directory of the last-used one.
    func profiles() -> (profiles: [BrowserProfile], lastUsed: String?) {
        let localState = supportURL.appendingPathComponent("Local State")
        var result: [BrowserProfile] = []
        var lastUsed: String?

        if let data = try? Data(contentsOf: localState),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profile = json["profile"] as? [String: Any] {
            lastUsed = profile["last_used"] as? String
            if let cache = profile["info_cache"] as? [String: Any] {
                for (dir, info) in cache {
                    let name = (info as? [String: Any])?["name"] as? String ?? dir
                    result.append(BrowserProfile(dir: dir, name: name))
                }
            }
        }

        // Fallback: scan for profile dirs that contain a Bookmarks file.
        if result.isEmpty {
            let fm = FileManager.default
            let entries = (try? fm.contentsOfDirectory(at: supportURL,
                                                       includingPropertiesForKeys: nil)) ?? []
            for e in entries where fm.fileExists(atPath: e.appendingPathComponent("Bookmarks").path) {
                result.append(BrowserProfile(dir: e.lastPathComponent, name: e.lastPathComponent))
            }
        }

        result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (result, lastUsed)
    }
}
