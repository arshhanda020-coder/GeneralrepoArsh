//
//  AddClassWorkView.swift
//  Odysseus
//
//  Quick way to log a dated test/quiz/assignment/project against a class —
//  reachable from Calendar's "+" so putting a date on something doesn't
//  require drilling into School > Class > Topic first. Finds-or-creates the
//  topic under the hood so it still shows up in the normal place afterward.
//

import SwiftUI
import SwiftData

struct AddClassWorkView: View {
    /// Defaults to the day being viewed when opened from Calendar.
    var presetDate: Date = .now

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]

    @State private var selectedClassID: String?
    @State private var selectedTopicID: String?
    @State private var newTopicName = ""
    @State private var title = ""
    @State private var type: AssignmentType = .test
    @State private var dueDate: Date
    @State private var remindersOn = false

    init(presetDate: Date = .now) {
        self.presetDate = presetDate
        _dueDate = State(initialValue: presetDate)
    }

    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }
    private var selectedClass: SchoolClass? { enrolledClasses.first { $0.id == selectedClassID } }
    private var existingTopics: [Topic] { selectedClass?.topics.filter { !$0.isSummerWork }.sorted { $0.sortIndex < $1.sortIndex } ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    Picker("Class", selection: $selectedClassID) {
                        Text("Select").tag(String?.none)
                        ForEach(enrolledClasses) { schoolClass in
                            Text(schoolClass.name).tag(Optional(schoolClass.id))
                        }
                    }
                }
                if selectedClass != nil {
                    Section("Topic") {
                        if existingTopics.isEmpty {
                            Text("No topics yet — one will be created below.")
                                .font(.caption)
                                .foregroundStyle(Theme.dimText)
                        } else {
                            Picker("Topic", selection: $selectedTopicID) {
                                Text("New topic").tag(String?.none)
                                ForEach(existingTopics) { topic in
                                    Text(topic.name).tag(Optional(topic.id))
                                }
                            }
                        }
                        if selectedTopicID == nil {
                            TextField("Topic name (e.g. Unit 4, Chapter 7)", text: $newTopicName)
                        }
                    }
                }
                Section("What is it") {
                    TextField("Title (e.g. \"Chapter 5 Test\")", text: $title)
                    Picker("Type", selection: $type) {
                        ForEach(AssignmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                    Toggle("Remind me", isOn: $remindersOn)
                }
            }
            .navigationTitle("Add Class Work")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        selectedClass != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (selectedTopicID != nil || !newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func save() {
        guard let schoolClass = selectedClass else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let topic: Topic
        if let selectedTopicID, let existing = existingTopics.first(where: { $0.id == selectedTopicID }) {
            topic = existing
        } else {
            let trimmedTopicName = newTopicName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTopicName.isEmpty else { return }
            let nextIndex = (schoolClass.topics.map(\.sortIndex).max() ?? -1) + 1
            let newTopic = Topic(name: trimmedTopicName, sortIndex: nextIndex, schoolClass: schoolClass)
            modelContext.insert(newTopic)
            topic = newTopic
        }

        let assignment = Assignment(title: trimmedTitle, dueDate: dueDate, topic: topic, remindersOn: remindersOn, type: type)
        modelContext.insert(assignment)
        NotificationManager.shared.sync(assignment: assignment)
        dismiss()
    }
}

#Preview {
    AddClassWorkView()
        .modelContainer(for: [SchoolClass.self, Topic.self, Assignment.self], inMemory: true)
}
