//
//  SchoolView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct SchoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]

    @State private var showingManageClasses = false

    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }
    private var droppedClasses: [SchoolClass] { allClasses.filter { !$0.isEnrolled } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                classesSection

                navLinkRow(destination: MyTestsView(), icon: "graduationcap.badge.plus", title: "My Tests")
                navLinkRow(destination: GPACalculatorView(), icon: "chart.pie.fill", title: "GPA Calculator")
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("School")
        .sectionAssistantButton(.school)
        .sheet(isPresented: $showingManageClasses) {
            ManageClassesView()
        }
    }

    private func navLinkRow<Destination: View>(destination: Destination, icon: String, title: String) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(Theme.primaryText)
            .padding(12)
            .glassPanel(cornerRadius: 10, borderColor: MindMapSection.school.accentColor.opacity(0.7))
        }
    }

    // MARK: - Classes

    private let classGridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CLASSES")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingManageClasses = true
                } label: {
                    Text("Manage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if allClasses.isEmpty {
                EmptyStateView(
                    icon: MindMapSection.school.symbolName,
                    title: "No classes yet",
                    message: "Tap Manage to add your schedule.",
                    tint: MindMapSection.school.accentColor
                )
                .glassPanel(cornerRadius: 14)
            } else {
                LazyVGrid(columns: classGridColumns, spacing: 12) {
                    ForEach(enrolledClasses) { schoolClass in
                        NavigationLink(destination: SchoolClassDetailView(schoolClass: schoolClass)) {
                            ClassCardView(schoolClass: schoolClass)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !droppedClasses.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOT ENROLLED")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        LazyVGrid(columns: classGridColumns, spacing: 12) {
                            ForEach(droppedClasses) { schoolClass in
                                NavigationLink(destination: SchoolClassDetailView(schoolClass: schoolClass)) {
                                    ClassCardView(schoolClass: schoolClass, isDropped: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SchoolView()
    }
    .modelContainer(for: [SchoolClass.self, Topic.self, Lesson.self, LessonMaterial.self, Assignment.self, Exam.self, StudySession.self, QuizSession.self, QuizQuestion.self], inMemory: true)
}
