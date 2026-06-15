//
//  FolderStore.swift
//  MenuBarFolder
//
//  Persists the LIST of pinned folders (one menu-bar icon each) as plain
//  bookmarks, so the set survives relaunches and keeps working if a folder
//  is moved or renamed.
//
//  Plain bookmarks (NOT `.withSecurityScope`): security-scoped bookmarks only
//  resolve inside a sandboxed app with the matching entitlement; in this
//  non-sandboxed binary they fail with NSCocoaErrorDomain 259. A plain
//  bookmark resolves fine and the binary already has full disk access.
//

import Foundation

final class FolderStore {

    private let key = "pinnedFolders"             // [Data] — array of bookmarks
    private let legacyKey = "pinnedFolderBookmark" // old single-folder bookmark

    /// The pinned folders, in display order.
    private(set) var folders: [URL] = []

    init() {
        load()
    }

    func contains(_ url: URL) -> Bool {
        folders.contains(url.standardizedFileURL)
    }

    @discardableResult
    func add(_ url: URL) -> Bool {
        let url = url.standardizedFileURL
        guard !folders.contains(url) else { return false }
        folders.append(url)
        save()
        return true
    }

    func remove(_ url: URL) {
        folders.removeAll { $0 == url.standardizedFileURL }
        save()
    }

    /// Swap one pinned folder for another, preserving its position.
    func replace(_ old: URL, with new: URL) {
        let new = new.standardizedFileURL
        if let i = folders.firstIndex(of: old.standardizedFileURL) {
            if folders.contains(new) {
                folders.remove(at: i)         // target already pinned — just drop the old slot
            } else {
                folders[i] = new
            }
        } else {
            folders.append(new)
        }
        save()
    }

    // MARK: - persistence

    private func load() {
        var urls: [URL] = []
        if let datas = UserDefaults.standard.array(forKey: key) as? [Data] {
            for data in datas {
                if let url = Self.resolve(data), !urls.contains(url) { urls.append(url) }
            }
        }
        // One-time migration from the old single-folder key.
        if let legacy = UserDefaults.standard.data(forKey: legacyKey) {
            if let url = Self.resolve(legacy), !urls.contains(url) { urls.append(url) }
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
        folders = urls
        save()   // normalize storage (re-mint bookmarks, finish migration)
    }

    private func save() {
        let datas: [Data] = folders.compactMap {
            try? $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(datas, forKey: key)
    }

    private static func resolve(_ data: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [],
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        return url.standardizedFileURL
    }
}
