//
//  ExtracurricularsView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct ExtracurricularsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Extracurricular.createdAt, order: .reverse) private var items: [Extracurricular]

    @State private var showingAdd = false
    @State private var editingItem: Extracurricular?
    @State private var goals: String = UserDefaults.standard.string(forKey: "extracurricular_goals") ?? ""
    @State private var isSuggesting = false
    @State private var suggestError: String?
    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                goalsSection

                if items.isEmpty {
                    Text("Nothing here yet. Tap + to add an activity, or tell Jarvis/Copilot what you're working on and it can draft one for you.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            row(item)
                        }
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))

                    Button {
                        exportResume()
                    } label: {
                        Label("Export Resume (PDF)", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(MindMapSection.extracurriculars.accentColor)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Extracurriculars")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddEditExtracurricularView(item: nil)
        }
        .sheet(item: $editingItem) { item in
            AddEditExtracurricularView(item: item)
        }
        .sheet(item: Binding(
            get: { shareURL.map { IdentifiableURL(url: $0) } },
            set: { shareURL = $0?.url }
        )) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GOALS")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(alignment: .leading, spacing: 10) {
                TextField("What are you trying to build toward? (e.g. college apps, a career in finance)", text: $goals, axis: .vertical)
                    .lineLimit(1...4)
                    .onChange(of: goals) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "extracurricular_goals")
                    }
                Button {
                    suggestActivities()
                } label: {
                    Label(isSuggesting ? "Thinking…" : "Suggest new activities", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.extracurriculars.accentColor)
                .disabled(isSuggesting || goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let suggestError {
                    Text(suggestError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private func row(_ item: Extracurricular) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                if item.isAISuggested {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(MindMapSection.extracurriculars.accentColor)
                }
                Spacer()
                if item.proofData != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.terminalGreen)
                }
                if let category = item.category, !category.isEmpty {
                    Text(category.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MindMapSection.extracurriculars.accentColor)
                }
            }
            if let collaborators = item.collaborators, !collaborators.isEmpty {
                Text("With \(collaborators)")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            if !item.activityDescription.isEmpty {
                Text(item.activityDescription)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
    }

    private func suggestActivities() {
        isSuggesting = true
        suggestError = nil
        let existing = items.map { $0.title }.joined(separator: ", ")
        let prompt = """
        Suggest 3 new extracurricular activities or opportunities that would genuinely help with this goal: \(goals)
        Activities already logged (don't repeat these): \(existing.isEmpty ? "none yet" : existing)
        For each, give a short title and a 1-sentence reason it fits the goal. Plain text, no markdown, numbered list.
        """
        Task {
            do {
                let text = try await AISettings.currentService.draft(prompt: prompt)
                modelContext.insert(Extracurricular(
                    title: "Suggestions for: \(goals)",
                    activityDescription: text,
                    category: "Suggestions",
                    isAISuggested: true
                ))
            } catch {
                suggestError = error.localizedDescription
            }
            isSuggesting = false
        }
    }

    private func exportResume() {
        let data = ExtracurricularResumeGenerator.makePDF(items: items, userName: "My")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Extracurriculars.pdf")
        try? data.write(to: url)
        shareURL = url
    }
}

#Preview {
    NavigationStack {
        ExtracurricularsView()
    }
    .modelContainer(for: [Extracurricular.self], inMemory: true)
}
