//
//  Favicons.swift
//  MenuBarFolder
//
//  Reads favicon PNGs from a Chromium profile's "Favicons" SQLite database.
//  Opened read-only with immutable=1 so it works even while the browser is
//  running (and holding a write lock). No third-party SQLite wrapper — the
//  system libsqlite3 is used directly.
//

import Foundation
import SQLite3

enum Favicons {

    /// Build `url -> PNG data` for the given bookmark URLs by reading the
    /// profile's Favicons DB. URLs without an exact page match fall back to any
    /// icon known for the same host. Raw `Data` (not NSImage) so the result is
    /// Sendable and can cross back to the main actor for image construction.
    static func data(profilePath: URL, for urls: [String]) -> [String: Data] {
        let dbPath = profilePath.appendingPathComponent("Favicons").path
        guard FileManager.default.fileExists(atPath: dbPath) else { return [:] }

        var db: OpaquePointer?
        let encoded = dbPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? dbPath
        let uri = "file:\(encoded)?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return [:]
        }
        defer { sqlite3_close(db) }

        // Largest bitmap per page URL (favicons are tiny; loading all is cheap).
        var pageData: [String: (w: Int32, data: Data)] = [:]
        var hostData: [String: (w: Int32, data: Data)] = [:]

        let sql = """
        SELECT m.page_url, b.image_data, b.width
        FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id = m.icon_id
        WHERE b.image_data IS NOT NULL
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
            let page = String(cString: cStr)
            let width = sqlite3_column_int(stmt, 2)
            guard let blob = sqlite3_column_blob(stmt, 1) else { continue }
            let bytes = Int(sqlite3_column_bytes(stmt, 1))
            guard bytes > 0 else { continue }
            let data = Data(bytes: blob, count: bytes)

            if let cur = pageData[page], cur.w >= width {} else {
                pageData[page] = (width, data)
            }
            if let host = URL(string: page)?.host {
                if let cur = hostData[host], cur.w >= width {} else {
                    hostData[host] = (width, data)
                }
            }
        }

        // Resolve only the URLs we actually need.
        var result: [String: Data] = [:]
        for url in urls {
            let entry = pageData[url] ?? URL(string: url).flatMap { $0.host }.flatMap { hostData[$0] }
            if let entry { result[url] = entry.data }
        }
        return result
    }
}
