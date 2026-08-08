//
//  ManageClassesView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct ManageClassesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SchoolClass.sortIndex) private var classes: [SchoolClass]

    @State private var newClassName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add a class") {
                    HStack {
                        TextField("e.g. AP Biology", text: $newClassName)
                            .onSubmit(addClass)
                        Button(action: addClass) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newClassName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Your classes") {
                    if classes.isEmpty {
                        Text("No classes yet.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    } else {
                        ForEach(classes) { schoolClass in
                            Toggle(isOn: Binding(
                                get: { schoolClass.isEnrolled },
                                set: { schoolClass.isEnrolled = $0 }
                            )) {
                                Text(schoolClass.name)
                            }
                            .tint(MindMapSection.school.accentColor)
                        }
                        .onDelete(perform: deleteClasses)
                    }
                }

                Section {
                    Text("Drop a class by unchecking it — it stays around so past assignments and tests keep their history. Swipe to delete it entirely.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
            }
            .navigationTitle("Classes")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addClass() {
        let trimmed = newClassName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (classes.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(SchoolClass(name: trimmed, isEnrolled: true, sortIndex: nextIndex))
        newClassName = ""
    }

    private func deleteClasses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(classes[index])
        }
    }
}

#Preview {
    ManageClassesView()
        .modelContainer(for: [SchoolClass.self], inMemory: true)
}
