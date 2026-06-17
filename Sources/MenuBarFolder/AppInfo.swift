//
//  AppInfo.swift
//  MenuBarFolder
//
//  Single source of truth for the app's identity, shown in the About tab.
//

import Foundation

enum AppInfo {
    static let name = "MenuBarFolder"
    static let version = "1.1.0"  // browser bookmarks, per-instance settings, Option actions
    static let tagline = "Your favourite folders, one click away in the menu bar."

    static let author = "iLya Os"
    static let homepage = "http://ctrl8.com/MenuBarFolder"
    static let github = "https://github.com/ilya000"
    static let license = "MIT"

    /// Lineage: the 1998 Windows ancestor of this app.
    static let heritageTitle = "Successor to TrayMenu (1998)"
    static let heritageURL = "https://old.osipov.ru/proge.htm"

    static let summary = """
    MenuBarFolder pins one or more folders to the macOS menu bar and lets you \
    browse each from its own dropdown — open files in their default app, dive \
    into subfolders as nested submenus, all without opening a Finder window.
    """
}
