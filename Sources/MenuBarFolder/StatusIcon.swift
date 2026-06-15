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
}
