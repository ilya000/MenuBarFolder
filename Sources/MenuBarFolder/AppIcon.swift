//
//  AppIcon.swift
//  MenuBarFolder
//
//  The application icon, drawn programmatically: a blue squircle with a white
//  folder and a blue "MB" label on its front face. Used in the About tab and
//  the top "MenuBarFolder" menu item. (The per-folder menu-bar icons are a
//  separate, monochrome template — see StatusIcon.)
//

import AppKit

enum AppIcon {

    static func make(size s: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: s, height: s))
        image.lockFocus()
        defer { image.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

        // Background squircle with a vertical gradient + soft top sheen.
        let rect = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.055, dy: s * 0.055)
        let radius = rect.width * 0.2237
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        ctx.saveGState()
        path.addClip()
        let colors = [
            NSColor(srgbRed: 0.40, green: 0.74, blue: 1.00, alpha: 1).cgColor,
            NSColor(srgbRed: 0.04, green: 0.40, blue: 0.93, alpha: 1).cgColor,
        ] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: rect.midX, y: rect.maxY),
                                   end: CGPoint(x: rect.midX, y: rect.minY), options: [])
        }
        let sheen = NSBezierPath(ovalIn: CGRect(x: rect.minX - rect.width * 0.1, y: rect.midY,
                                                width: rect.width * 1.2, height: rect.height * 0.8))
        NSColor(white: 1, alpha: 0.10).setFill()
        sheen.fill()
        ctx.restoreGState()

        // White folder with a soft drop shadow.
        let folderConfig = NSImage.SymbolConfiguration(pointSize: s * 0.46, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        guard let folder = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(folderConfig) else { return image }

        let fw = folder.size.width, fh = folder.size.height
        let fr = CGRect(x: (s - fw) / 2, y: (s - fh) / 2 + s * 0.03, width: fw, height: fh)
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(srgbRed: 0, green: 0.12, blue: 0.4, alpha: 0.35)
        shadow.shadowBlurRadius = s * 0.03
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
        shadow.set()
        folder.draw(in: fr)
        NSGraphicsContext.current?.restoreGraphicsState()

        // "MB" in blue on the folder's front face.
        let baseFont = NSFont.systemFont(ofSize: s * 0.205, weight: .heavy)
        let font = NSFont(descriptor: baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor,
                          size: s * 0.205) ?? baseFont
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: 0.06, green: 0.42, blue: 0.92, alpha: 1),
            .paragraphStyle: para,
            .kern: s * 0.004,
        ]
        let str = NSAttributedString(string: "MB", attributes: attrs)
        let ts = str.size()
        str.draw(at: CGPoint(x: (s - ts.width) / 2, y: fr.minY + fr.height * 0.085))

        return image
    }
}
