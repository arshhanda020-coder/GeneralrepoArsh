//
//  NoteExportGenerator.swift
//  Odysseus
//
//  Renders a single freeform `Note` — title, color stripe, body text, and any
//  attached images — into a one-file PDF that can be handed to `ShareSheet`.
//  Built on CoreText + CoreGraphics directly, same approach as
//  `ExtracurricularResumeGenerator`, so it compiles and draws identically on
//  iOS/iPadOS and macOS with no per-platform fork.
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO

enum NoteExportGenerator {
    /// Takes plain values rather than a `Note` so callers can export an
    /// in-progress draft (unsaved title/color/images) without inserting a
    /// throwaway `Note` model instance into a context just to read it back.
    static func makePDF(
        title: String,
        content: String,
        colorHex: String?,
        imageDatas: [Data],
        updatedAt: Date,
        defaultColorHex: String
    ) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
        let metaFont = CTFontCreateWithName("Helvetica-Oblique" as CFString, 10, nil)
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let darkGray = CGColor(red: 85.0 / 255, green: 85.0 / 255, blue: 85.0 / 255, alpha: 1)
        let accent = cgColor(hex: colorHex ?? defaultColorHex)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return Data()
        }

        var y: CGFloat = margin
        context.beginPDFPage(nil)

        func newPageIfNeeded(_ neededHeight: CGFloat) {
            if y + neededHeight > pageHeight - margin {
                context.endPDFPage()
                context.beginPDFPage(nil)
                y = margin
            }
        }

        func draw(_ text: String, font: CTFont, color: CGColor = black, spacingAfter: CGFloat = 8) {
            let attributed = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            ])
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let fitSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter, CFRange(location: 0, length: 0), nil,
                CGSize(width: contentWidth, height: .greatestFiniteMagnitude), nil
            )
            newPageIfNeeded(fitSize.height + spacingAfter)

            // CoreGraphics/CoreText's origin is bottom-left; flip so `y` keeps reading top-down.
            let frameRect = CGRect(x: margin, y: pageHeight - y - fitSize.height, width: contentWidth, height: fitSize.height)
            let ctFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: frameRect, transform: nil), nil)
            context.saveGState()
            CTFrameDraw(ctFrame, context)
            context.restoreGState()

            y += fitSize.height + spacingAfter
        }

        // Color stripe under the title, so the note's chosen color survives export.
        newPageIfNeeded(4)
        context.saveGState()
        context.setFillColor(accent)
        context.fill(CGRect(x: margin, y: pageHeight - y - 4, width: contentWidth, height: 4))
        context.restoreGState()
        y += 10

        draw(title, font: titleFont, spacingAfter: 4)
        draw("Exported \(updatedAt.formatted(date: .abbreviated, time: .shortened))", font: metaFont, color: darkGray, spacingAfter: 16)

        if !content.isEmpty {
            draw(content, font: bodyFont, spacingAfter: 16)
        }

        for imageData in imageDatas {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
            let aspect = CGFloat(cgImage.height) / CGFloat(cgImage.width)
            let drawWidth = min(contentWidth, CGFloat(cgImage.width))
            let drawHeight = drawWidth * aspect
            let cappedHeight = min(drawHeight, pageHeight - margin * 2)
            let cappedWidth = cappedHeight < drawHeight ? cappedHeight / aspect : drawWidth

            newPageIfNeeded(cappedHeight + 12)
            let imageRect = CGRect(x: margin, y: pageHeight - y - cappedHeight, width: cappedWidth, height: cappedHeight)
            context.draw(cgImage, in: imageRect)
            y += cappedHeight + 12
        }

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private static func cgColor(hex: String) -> CGColor {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.hasPrefix("#") ? String(sanitized.dropFirst()) : sanitized
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }
}
