//
//  LoginItem.swift
//  MenuBarFolder
//
//  "Start at Login" implemented as a per-user LaunchAgent. We can't use
//  SMAppService.mainApp here because that requires a real .app bundle; this
//  is a bare executable, so we write a LaunchAgent plist pointing at the
//  current binary and (de)register it with launchctl.
//

import Foundation

enum LoginItem {

    static let label = "com.ctrl8.menubarfolder"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Whether the LaunchAgent is currently installed.
    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Install or remove the LaunchAgent. Returns false if a step failed, so
    /// the caller can avoid flipping the checkmark.
    @discardableResult
    static func setEnabled(_ enable: Bool) -> Bool {
        enable ? install() : remove()
    }

    // MARK: - private

    private static func install() -> Bool {
        guard let exe = Bundle.main.executablePath else {
            NSLog("MenuBarFolder: can't resolve executable path for login item")
            return false
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)
            // Best-effort load into the current GUI session. Deprecated but
            // still functional and the simplest broadly-compatible call.
            launchctl(["load", "-w", plistURL.path])
            return true
        } catch {
            NSLog("MenuBarFolder: failed to install login item: \(error)")
            return false
        }
    }

    private static func remove() -> Bool {
        guard isEnabled else { return true }
        launchctl(["unload", "-w", plistURL.path])
        do {
            try FileManager.default.removeItem(at: plistURL)
            return true
        } catch {
            NSLog("MenuBarFolder: failed to remove login item: \(error)")
            return false
        }
    }

    private static func launchctl(_ args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        do { try task.run(); task.waitUntilExit() }
        catch { NSLog("MenuBarFolder: launchctl \(args) failed: \(error)") }
    }
}
