//
//  AskAIHelpBox.swift
//  Odysseus
//
//  Reusable "ask AI for help" box — a question plus an optional photo,
//  answered by the current AI provider. Dropped in wherever it's actually
//  useful (a topic, a lesson, a specific assignment/test) instead of sitting
//  as one generic box at the top of School; `contextLabel` just flavors the
//  prompt so the AI knows what it's helping with.
//

import SwiftUI
import PhotosUI

struct AskAIHelpBox: View {
    var contextLabel: String

    @State private var question = ""
    @State private var photo: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var answer: String?
    @State private var isAsking = false
    @State private var askError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASK AI FOR HELP")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let imageData, let uiImage = PlatformImage(data: imageData) {
                    Image(platformImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 8) {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Image(systemName: "camera")
                            .foregroundStyle(Theme.dimText)
                    }
                    .buttonStyle(.plain)

                    TextField("What do you need help with?", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit {
                            guard !isAsking, !(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData == nil) else { return }
                            ask()
                        }
                }

                Button {
                    ask()
                } label: {
                    Label(isAsking ? "Thinking…" : "Ask", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.school.accentColor)
                .disabled(isAsking || (question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData == nil))

                if let askError {
                    Text(askError).font(.caption).foregroundStyle(Theme.negative)
                }

                if let answer {
                    Divider().overlay(Theme.cardBorder)
                    Text(answer)
                        .font(.caption)
                        .foregroundStyle(Theme.primaryText)
                }
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
        .onChange(of: photo) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    imageData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                }
            }
        }
    }

    private func ask() {
        isAsking = true
        askError = nil
        answer = nil
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = trimmed.isEmpty ? "Explain what's shown in this photo and walk me through how to solve it, step by step." : trimmed
        let image = imageData

        Task {
            do {
                let result = try await AISettings.currentService.askAboutImage(
                    prompt: "Regarding \(contextLabel): \(prompt)",
                    imageData: image,
                    systemPrompt: "You are a patient, encouraging tutor. Explain concepts step by step so the student actually understands the reasoning, not just the answer. Keep it focused and not overly long."
                )
                answer = result
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }
}
