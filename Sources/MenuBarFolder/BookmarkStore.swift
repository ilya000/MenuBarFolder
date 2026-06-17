//
//  BookmarkStore.swift
//  MenuBarFolder
//
//  Persists the list of pinned browser-bookmark sources (browser + profile),
//  parallel to FolderStore which persists pinned folders.
//

import Foundation

/// A pinned bookmark source: one browser profile shown as a menu-bar icon.
struct BookmarkSource: Codable, Equatable, Hashable, Identifiable {
    let browserID: String   // Browser.id, e.g. "chrome"
    let profileDir: String  // on-disk profile dir, e.g. "Profile 4"
    var id: String { "\(browserID)/\(profileDir)" }
}

final class BookmarkStore {

    private let key = "bookmarkSources"
    private(set) var sources: [BookmarkSource] = []

    init() { load() }

    func contains(_ s: BookmarkSource) -> Bool { sources.contains(s) }

    @discardableResult
    func add(_ s: BookmarkSource) -> Bool {
        guard !sources.contains(s) else { return false }
        sources.append(s)
        save()
        return true
    }

    func remove(_ s: BookmarkSource) {
        sources.removeAll { $0 == s }
        save()
    }

    // MARK: - persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BookmarkSource].self, from: data) else { return }
        sources = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
