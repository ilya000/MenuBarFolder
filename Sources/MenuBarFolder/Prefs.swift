//
//  Prefs.swift
//  MenuBarFolder
//
//  Per-instance display preferences (sort order + folder grouping). Each
//  pinned folder keeps its OWN settings, keyed by its path, so two menu-bar
//  folders can sort differently.
//

import Foundation

/// How entries inside a folder menu are ordered.
enum SortMode: String, CaseIterable, Codable, Sendable {
    case name          // A → Z
    case dateAdded     // newest added first
    case dateModified  // most recently modified first
    case size          // largest first

    var title: String {
        switch self {
        case .name:         return "Name (A–Z)"
        case .dateAdded:    return "Date added (newest)"
        case .dateModified: return "Date modified (newest)"
        case .size:         return "Size (largest)"
        }
    }
}

/// The options handed to the background directory reader.
struct DisplayOptions: Codable, Sendable {
    var sort: SortMode
    var foldersOnTop: Bool

    /// Default for a folder that has never been configured.
    static let `default` = DisplayOptions(sort: .dateAdded, foldersOnTop: true)
}

/// How bookmark entries are ordered. Unlike folders, the default is the
/// browser's own order, and there is no size option.
enum BookmarkSortMode: String, CaseIterable, Codable, Sendable {
    case browser       // as stored in the browser
    case name          // A → Z
    case dateAdded     // newest added first

    var title: String {
        switch self {
        case .browser:   return "Browser order"
        case .name:      return "Name (A–Z)"
        case .dateAdded: return "Date added (newest)"
        }
    }
}

struct BookmarkDisplayOptions: Codable, Sendable {
    var sort: BookmarkSortMode
    var foldersOnTop: Bool

    /// Default: exactly as the browser shows them.
    static let `default` = BookmarkDisplayOptions(sort: .browser, foldersOnTop: false)
}

/// Per-instance display preferences, persisted as `id -> options`. Folder and
/// bookmark instances use separate keyspaces.
enum InstancePrefs {

    private static let folderKey = "instanceDisplay"
    private static let bookmarkKey = "instanceBookmarkDisplay"

    // Folders
    static func options(for id: String) -> DisplayOptions { load(folderKey)[id] ?? .default }
    static func set(_ options: DisplayOptions, for id: String) { save(options, id, folderKey) }

    // Bookmarks
    static func bookmarkOptions(for id: String) -> BookmarkDisplayOptions { load(bookmarkKey)[id] ?? .default }
    static func setBookmark(_ options: BookmarkDisplayOptions, for id: String) { save(options, id, bookmarkKey) }

    // MARK: storage

    private static func load<T: Codable>(_ key: String) -> [String: T] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: T].self, from: data) else { return [:] }
        return decoded
    }

    private static func save<T: Codable>(_ value: T, _ id: String, _ key: String) {
        var all: [String: T] = load(key)
        all[id] = value
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
