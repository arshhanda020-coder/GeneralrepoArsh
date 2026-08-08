//
//  PlatformImage.swift
//  Odysseus
//
//  UIImage on iOS/iPadOS, NSImage on macOS — one name so the many views that
//  decode a stored photo (food log, workout log, body progress, homework,
//  extracurricular proof, Copilot attachments) don't need per-platform
//  branches of their own.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

#if canImport(AppKit)
extension NSImage {
    /// NSImage has no built-in JPEG encoder — UIImage's `jpegData(compressionQuality:)`
    /// has to be rebuilt on top of NSBitmapImageRep so the call sites that
    /// re-compress a picked photo before storing it can stay identical on both platforms.
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
#endif
