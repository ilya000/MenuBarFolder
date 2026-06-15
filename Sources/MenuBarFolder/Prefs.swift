//
//  Prefs.swift
//  MenuBarFolder
//
//  Global display preferences (sort order + folder grouping), backed by
//  UserDefaults and shared by every menu-bar icon.
//

import Foundation

/// How entries inside a folder menu are ordered.
enum SortMode: String, CaseIterable, Sendable {
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
struct DisplayOptions: Sendable {
    var sort: SortMode
    var foldersOnTop: Bool
}

enum AppPrefs {

    private static let sortKey = "sortMode"
    private static let foldersOnTopKey = "foldersOnTop"

    /// Register defaults once at launch: newest-first, folders grouped on top —
    /// matching the app's original behaviour.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            sortKey: SortMode.dateAdded.rawValue,
            foldersOnTopKey: true,
        ])
    }

    static var sortMode: SortMode {
        get { SortMode(rawValue: UserDefaults.standard.string(forKey: sortKey) ?? "") ?? .dateAdded }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sortKey) }
    }

    static var foldersOnTop: Bool {
        get { UserDefaults.standard.bool(forKey: foldersOnTopKey) }
        set { UserDefaults.standard.set(newValue, forKey: foldersOnTopKey) }
    }

    static var displayOptions: DisplayOptions {
        DisplayOptions(sort: sortMode, foldersOnTop: foldersOnTop)
    }
}
