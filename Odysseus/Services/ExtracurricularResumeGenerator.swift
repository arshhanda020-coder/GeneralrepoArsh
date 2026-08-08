//
//  ExtracurricularResumeGenerator.swift
//  Odysseus
//
//  Renders every logged extracurricular into a simple one-page-per-overflow
//  PDF resume. Built on CoreText + CoreGraphics directly (CTFont/CTFrame,
//  a CGContext PDF consumer) rather than UIGraphicsPDFRenderer, so the same
//  code draws the PDF on iOS/iPadOS and macOS — no per-platform UIKit/AppKit
//  fork needed, and no third-party dependency.
//

import Foundation
import CoreGraphics
import CoreText

enum ExtracurricularResumeGenerator {
    static func makePDF(items: [Extracurricular], userName: String) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
        let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 13, nil)
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let metaFont = CTFontCreateWithName("Helvetica-Oblique" as CFString, 10, nil)
        let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let darkGray = CGColor(red: 85.0 / 255, green: 85.0 / 255, blue: 85.0 / 255, alpha: 1)

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

        func draw(_ text: String, font: CTFont, color: CGColor = black, spacingAfter: CGFloat = 4) {
            // NSAttributedString.Key.font/.foregroundColor are UIKit/AppKit
            // overlay additions, not plain Foundation — using the raw CoreText
            // attribute constants instead keeps this file free of both, so it
            // compiles identically on iOS and macOS.
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

        draw("\(userName) — Extracurricular Activities", font: titleFont, spacingAfter: 16)

        if items.isEmpty {
            draw("No activities logged yet.", font: bodyFont)
        }

        for item in items.sorted(by: { $0.createdAt < $1.createdAt }) {
            newPageIfNeeded(40)
            draw(item.title, font: headerFont, spacingAfter: 2)

            var metaParts: [String] = []
            if let category = item.category, !category.isEmpty { metaParts.append(category) }
            if let collaborators = item.collaborators, !collaborators.isEmpty { metaParts.append("With: \(collaborators)") }
            if !metaParts.isEmpty {
                draw(metaParts.joined(separator: "  •  "), font: metaFont, color: darkGray, spacingAfter: 3)
            }

            if !item.activityDescription.isEmpty {
                draw(item.activityDescription, font: bodyFont, spacingAfter: 14)
            } else {
                y += 10
            }
        }

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
