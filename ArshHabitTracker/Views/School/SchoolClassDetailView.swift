//
//  SchoolClassDetailView.swift
//  ArshHabitTracker
//
//  Full-screen list of topics within one class. Topics are where assignments
//  actually live and what Test Me quizzes you on.
//

import SwiftUI
import SwiftData

struct SchoolClassDetailView: View {
    @Bindable var schoolClass: SchoolClass

    @Environment(\.modelContext) private var modelContext
    @State private var newTopicName = ""

    private var topics: [Topic] { schoolClass.topics.sorted { $0.sortIndex < $1.sortIndex } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    TextField("Add a topic (e.g. Recursion, Photosynthesis)", text: $newTopicName)
                        .padding(10)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                        .onSubmit(addTopic)
                    Button(action: addTopic) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : MindMapSection.school.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if topics.isEmpty {
                    Text("No topics yet. Add a unit or lesson above, then log its assignments and test yourself on it.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            topicRow(topic)
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
        .navigationTitle(schoolClass.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func topicRow(_ topic: Topic) -> some View {
        NavigationLink(destination: TopicDetailView(topic: topic)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(topic.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    let pending = topic.assignments.filter { !$0.isDone }.count
                    Text(pending == 0 ? "All caught up" : "\(pending) pending")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addTopic() {
        let trimmed = newTopicName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (topics.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(Topic(name: trimmed, sortIndex: nextIndex, schoolClass: schoolClass))
        newTopicName = ""
    }
}
