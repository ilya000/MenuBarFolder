//
//  BookmarkTree.swift
//  MenuBarFolder
//
//  In-memory model of a browser's bookmark tree plus a parser for the
//  Chromium "Bookmarks" JSON file. The whole file is small, so it's parsed
//  in one shot (no lazy reads like the filesystem source needs).
//

import Foundation

/// A node in the bookmark tree: a folder (with children) or a link.
struct BookmarkItem: Sendable {
    let title: String
    let url: String?            // nil → folder
    let children: [BookmarkItem]
    let dateAdded: Date?

    var isFolder: Bool { url == nil }

    /// Display title, falling back to the URL's host for unnamed toolbar links.
    var displayTitle: String {
        if !title.isEmpty { return title }
        if let url, let host = URL(string: url)?.host { return host }
        return url ?? "(untitled)"
    }
}

enum BookmarkParser {

    /// Parse the Chromium Bookmarks JSON at `path` into a flat top-level list:
    /// the bookmarks-bar entries first, then an "Other Bookmarks" folder if it
    /// has any. Returns an empty array if the file is missing or unreadable.
    static func parse(profilePath: URL) -> [BookmarkItem] {
        let file = profilePath.appendingPathComponent("Bookmarks")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["roots"] as? [String: Any] else {
            return []
        }

        var top: [BookmarkItem] = []
        if let bar = roots["bookmark_bar"] as? [String: Any] {
            top.append(contentsOf: children(of: bar))
        }
        if let other = roots["other"] as? [String: Any] {
            let kids = children(of: other)
            if !kids.isEmpty {
                top.append(BookmarkItem(title: "Other Bookmarks", url: nil, children: kids, dateAdded: nil))
            }
        }
        return top
    }

    /// Convert a Chromium `date_added` (microseconds since 1601-01-01 UTC).
    private static func chromeDate(_ s: Any?) -> Date? {
        guard let str = s as? String, let micros = Int64(str) else { return nil }
        return Date(timeIntervalSince1970: Double(micros) / 1_000_000 - 11_644_473_600)
    }

    private static func children(of node: [String: Any]) -> [BookmarkItem] {
        guard let kids = node["children"] as? [[String: Any]] else { return [] }
        return kids.compactMap(item(from:))
    }

    private static func item(from node: [String: Any]) -> BookmarkItem? {
        let name = node["name"] as? String ?? ""
        let added = chromeDate(node["date_added"])
        switch node["type"] as? String {
        case "url":
            guard let url = node["url"] as? String else { return nil }
            return BookmarkItem(title: name, url: url, children: [], dateAdded: added)
        case "folder":
            return BookmarkItem(title: name, url: nil, children: children(of: node), dateAdded: added)
        default:
            return nil
        }
    }

    /// Collect every link URL in the tree (for favicon prefetch).
    static func allURLs(_ items: [BookmarkItem]) -> [String] {
        var out: [String] = []
        for i in items {
            if let u = i.url { out.append(u) }
            out.append(contentsOf: allURLs(i.children))
        }
        return out
    }
}

enum BookmarkSort {

    /// Apply per-instance ordering recursively (folders sort their own
    /// children the same way).
    static func apply(_ items: [BookmarkItem], _ opt: BookmarkDisplayOptions) -> [BookmarkItem] {
        var arr = items.map { item -> BookmarkItem in
            guard item.isFolder else { return item }
            return BookmarkItem(title: item.title, url: nil,
                                children: apply(item.children, opt), dateAdded: item.dateAdded)
        }

        switch opt.sort {
        case .browser:
            break
        case .name:
            arr.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .dateAdded:
            arr.sort { a, b in
                switch (a.dateAdded, b.dateAdded) {
                case let (x?, y?) where x != y: return x > y
                case (.some, .none): return true
                case (.none, .some): return false
                default: return a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle) == .orderedAscending
                }
            }
        }

        if opt.foldersOnTop {
            arr = arr.filter { $0.isFolder } + arr.filter { !$0.isFolder }
        }
        return arr
    }
}
