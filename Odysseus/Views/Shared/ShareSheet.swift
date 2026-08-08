//
//  ShareSheet.swift
//  Odysseus
//

import SwiftUI

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
import AppKit

/// macOS has no sheet-presented share UI — NSSharingServicePicker is a
/// popover anchored to a view — so this wraps an invisible NSView and pops
/// the picker from it as soon as it appears, giving callers the same
/// "present as a sheet, get a share UI" behavior as the iOS wrapper above.
struct ShareSheet: NSViewRepresentable {
    let items: [Any]

    @Environment(\.dismiss) private var dismiss

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.delegate = context.coordinator
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, NSSharingServicePickerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            dismiss()
        }
    }
}
#endif
