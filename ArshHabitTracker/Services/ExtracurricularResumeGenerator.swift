//
//  ExtracurricularResumeGenerator.swift
//  ArshHabitTracker
//
//  Renders every logged extracurricular into a simple one-page-per-overflow
//  PDF resume via UIGraphicsPDFRenderer — no third-party dependency needed.
//

import Foundation
import UIKit

enum ExtracurricularResumeGenerator {
    static func makePDF(items: [Extracurricular], userName: String) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let headerFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let metaFont = UIFont.italicSystemFont(ofSize: 10)

        return renderer.pdfData { context in
            var y: CGFloat = margin
            context.beginPage()

            func newPageIfNeeded(_ neededHeight: CGFloat) {
                if y + neededHeight > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func draw(_ text: String, font: UIFont, color: UIColor = .black, spacingAfter: CGFloat = 4) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil
                )
                newPageIfNeeded(bounding.height + spacingAfter)
                (text as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height),
                    withAttributes: attributes
                )
                y += bounding.height + spacingAfter
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
                    draw(metaParts.joined(separator: "  •  "), font: metaFont, color: .darkGray, spacingAfter: 3)
                }

                if !item.activityDescription.isEmpty {
                    draw(item.activityDescription, font: bodyFont, spacingAfter: 14)
                } else {
                    y += 10
                }
            }
        }
    }
}
