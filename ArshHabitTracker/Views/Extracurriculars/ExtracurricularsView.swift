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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
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
    }

    private func row(_ item: Extracurricular) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if item.isAISuggested {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(MindMapSection.extracurriculars.accentColor)
                }
                Spacer()
                if let category = item.category, !category.isEmpty {
                    Text(category.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MindMapSection.extracurriculars.accentColor)
                }
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
}

#Preview {
    NavigationStack {
        ExtracurricularsView()
    }
    .modelContainer(for: [Extracurricular.self], inMemory: true)
}
