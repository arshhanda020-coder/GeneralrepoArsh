//
//  NoteCanvasView.swift
//  Odysseus
//
//  A Notability-style handwriting surface for `Note.drawingData`: a
//  PencilKit canvas with the system tool picker (pen, marker, pencil,
//  eraser, lasso, ruler) on faint ruled paper, sized to scroll like a real
//  notepad page rather than clip at one screen. Primary input is Apple
//  Pencil on iPad, but the canvas honors the system's "Only Draw with Apple
//  Pencil" setting so finger input works too when that's off.
//
//  PencilKit only exists on iOS/iPadOS (not plain macOS AppKit), so the Mac
//  target gets a small explanatory fallback instead — see the `#else` below.
//

import SwiftUI
import SwiftData

#if os(iOS)
import PencilKit

struct NoteCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?

    /// How tall the scrollable page is beyond one screen — gives room to
    /// keep writing down the page the way a real notepad would.
    private let pageHeight: CGFloat = 2400

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .default
        canvas.backgroundColor = .clear
        canvas.alwaysBounceVertical = true
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 4

        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        guard canvas.bounds.width > 0 else { return }
        let targetSize = CGSize(width: canvas.bounds.width, height: max(canvas.bounds.height, pageHeight))
        if canvas.contentSize != targetSize {
            canvas.contentSize = targetSize
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: canvas)
        coordinator.toolPicker?.removeObserver(canvas)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: NoteCanvasView
        var toolPicker: PKToolPicker?

        init(_ parent: NoteCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}

#else

/// macOS has no Apple Pencil input and no PencilKit — text notes remain the
/// way to write a note on the Mac target.
struct NoteCanvasView: View {
    @Binding var drawingData: Data?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "pencil.and.scribble")
                .font(.system(size: 34))
                .foregroundStyle(Theme.dimText)
            Text("Drawing is available on iPad with Apple Pencil.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

/// Faint ruled-paper lines drawn behind the canvas, purely decorative —
/// gives the writing surface the Notability-style notepad look.
struct RuledPaperBackground: View {
    var lineSpacing: CGFloat = 32

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = lineSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Theme.cardBorder), lineWidth: 0.5)
                y += lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Full-screen writing surface for a single note's drawing — the
/// Notability-style "open the page and write" flow, reached from
/// `NoteEditSheet`'s pencil button.
struct NoteDrawingSheet: View {
    @Bindable var note: Note
    var accentColor: Color = MindMapSection.notes.accentColor

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ZStack(alignment: .top) {
                    RuledPaperBackground()
                    NoteCanvasView(drawingData: $note.drawingData)
                }
                .frame(minHeight: 2400)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(note.title.isEmpty ? "Drawing" : note.title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        note.updatedAt = .now
                        dismiss()
                    }
                    .tint(accentColor)
                }
            }
        }
    }
}

#Preview {
    NoteDrawingSheet(note: Note(title: "Scratch"))
        .modelContainer(for: [Note.self], inMemory: true)
}
