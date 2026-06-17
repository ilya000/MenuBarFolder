//
//  StatusIcon.swift
//  MenuBarFolder
//
//  Builds the composite menu-bar image: a folder glyph with the pinned
//  folder's first two letters drawn large over its bottom-right corner.
//

import AppKit

enum StatusIcon {

    /// Compose a single template image. A transparent "notch" is punched
    /// behind the letters so the folder outline doesn't blur into them.
    /// Template = the menu bar tints it for light/dark automatically.
    static func make(letters: String) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        // Folder glyph, nudged up a touch to leave room for the letters.
        let folderConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        if let folder = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
            .withSymbolConfiguration(folderConfig) {
            let fs = folder.size
            let rect = NSRect(x: (size.width - fs.width) / 2,
                              y: (size.height - fs.height) / 2 + 1.5,
                              width: fs.width, height: fs.height)
            folder.draw(in: rect)
        }

        if !letters.isEmpty {
            let font = NSFont.systemFont(ofSize: 11, weight: .heavy)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,   // tinted by the menu bar (template)
            ]
            let str = NSAttributedString(string: letters, attributes: attrs)
            let ts = str.size()
            let origin = NSPoint(x: size.width - ts.width - 0.5, y: -0.5)

            // Punch a transparent rounded notch behind the text.
            if let ctx = NSGraphicsContext.current {
                ctx.saveGraphicsState()
                ctx.compositingOperation = .clear
                let pad: CGFloat = 1.0
                let hole = NSRect(x: origin.x - pad, y: origin.y - pad,
                                  width: ts.width + pad * 2, height: ts.height + pad * 2)
                NSBezierPath(roundedRect: hole, xRadius: 2, yRadius: 2).fill()
                ctx.restoreGraphicsState()
            }

            str.draw(at: origin)
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Folder glyph with a small colored browser icon — used for bookmark
    /// instances so you can tell which browser they came from. NOT a template
    /// (the browser badge is colorful); the folder is drawn in `labelColor`
    /// via a block-based image so it still adapts to a light/dark menu bar.
    ///
    /// When `profileLetters` is given (several profiles of the same browser are
    /// pinned), two profile letters sit in the folder's bottom-right corner and
    /// the browser badge shifts to the far right — so the profiles are
    /// distinguishable. Otherwise just the folder + browser badge.
    static func make(browserIcon: NSImage, profileLetters: String? = nil) -> NSImage {
        let hasLetters = !(profileLetters?.isEmpty ?? true)
        let size = NSSize(width: hasLetters ? 30 : 22, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Folder glyph (left area when there are letters), label-colored.
            let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
            let folderCenterX = hasLetters ? 10.0 : rect.width / 2
            if let folder = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) {
                let fs = folder.size
                let fr = NSRect(x: folderCenterX - fs.width / 2,
                                y: (rect.height - fs.height) / 2 + 1.5,
                                width: fs.width, height: fs.height)
                folder.draw(in: fr)
            }

            func punch(_ r: NSRect) {
                guard let ctx = NSGraphicsContext.current else { return }
                ctx.saveGraphicsState()
                ctx.compositingOperation = .clear
                NSBezierPath(roundedRect: r.insetBy(dx: -1.2, dy: -1.2), xRadius: 3, yRadius: 3).fill()
                ctx.restoreGraphicsState()
            }

            if hasLetters, let letters = profileLetters {
                // Two profile letters in the folder's bottom-right corner.
                let font = NSFont.systemFont(ofSize: 9, weight: .heavy)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
                let str = NSAttributedString(string: letters, attributes: attrs)
                let ts = str.size()
                let origin = NSPoint(x: folderCenterX + 7 - ts.width, y: -0.5)
                punch(NSRect(origin: origin, size: ts))
                str.draw(at: origin)

                // Browser badge at the far right.
                let badge = NSRect(x: rect.width - 11, y: 4, width: 10, height: 10)
                punch(badge)
                browserIcon.draw(in: badge, from: .zero, operation: .sourceOver, fraction: 1)
            } else {
                // Single profile: browser badge in the folder's bottom-right.
                let badge = NSRect(x: rect.width - 13, y: 0, width: 12, height: 12)
                punch(badge)
                browserIcon.draw(in: badge, from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
