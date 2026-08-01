//
//  SchoolView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData
import PhotosUI

struct SchoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]
    @Query(sort: \Exam.examDate) private var exams: [Exam]

    @State private var showingManageClasses = false
    @State private var showingAddExam = false
    @State private var editingExam: Exam?
    @State private var loggingExam: Exam?

    @State private var homeworkQuestion = ""
    @State private var homeworkPhoto: PhotosPickerItem?
    @State private var homeworkImageData: Data?
    @State private var homeworkAnswer: String?
    @State private var isAsking = false
    @State private var askError: String?

    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }
    private var droppedClasses: [SchoolClass] { allClasses.filter { !$0.isEnrolled } }
    private var upcomingExams: [Exam] { exams.filter { !$0.isPast } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                classesSection
                examsSection
                homeworkHelperSection

                NavigationLink(destination: TestMeView()) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("Test Me")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(MindMapSection.school.accentColor.opacity(0.7), lineWidth: 1))
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("School")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExam = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExam) {
            AddEditExamView(exam: nil)
        }
        .sheet(item: $editingExam) { exam in
            AddEditExamView(exam: exam)
        }
        .sheet(item: $loggingExam) { exam in
            LogStudySessionSheet(exam: exam)
        }
        .sheet(isPresented: $showingManageClasses) {
            ManageClassesView()
        }
    }

    // MARK: - Classes

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CLASSES")
                    .font(.caption2.weight(.bold))
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
                Text("No classes yet. Tap Manage to add your schedule.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(enrolledClasses.enumerated()), id: \.element.id) { index, schoolClass in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        classRow(schoolClass)
                    }
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))

                if !droppedClasses.isEmpty {
                    Text("Not enrolled: \(droppedClasses.map(\.name).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
        }
    }

    private func classRow(_ schoolClass: SchoolClass) -> some View {
        NavigationLink(destination: SchoolClassDetailView(schoolClass: schoolClass)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(schoolClass.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    let pendingCount = schoolClass.topics.flatMap(\.assignments).filter { !$0.isDone }.count
                    Text(schoolClass.topics.isEmpty ? "No topics yet" : (pendingCount == 0 ? "All caught up" : "\(pendingCount) pending"))
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

    // MARK: - Exams

    private var examsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UPCOMING TESTS")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if upcomingExams.isEmpty {
                Text("No tests scheduled. Tap the calendar icon to add SAT, ACT, AP exams, or class tests.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                ForEach(upcomingExams) { exam in
                    examCard(exam)
                }
            }
        }
    }

    private func examCard(_ exam: Exam) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(exam.examDate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(exam.daysUntil)")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(MindMapSection.school.accentColor)
                    Text(exam.daysUntil == 1 ? "day" : "days")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                .frame(width: 52)
                Button {
                    editingExam = exam
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.dimText)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("\(exam.studySessions.count) study sessions logged")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button("Log session") { loggingExam = exam }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(MindMapSection.school.accentColor)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - AI homework helper

    private var homeworkHelperSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASK AI FOR HELP")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let homeworkImageData, let uiImage = UIImage(data: homeworkImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 8) {
                    PhotosPicker(selection: $homeworkPhoto, matching: .images) {
                        Image(systemName: "camera")
                            .foregroundStyle(Theme.dimText)
                    }
                    .buttonStyle(.plain)

                    TextField("What do you need help with?", text: $homeworkQuestion, axis: .vertical)
                        .lineLimit(1...4)
                }

                Button {
                    askForHelp()
                } label: {
                    Label(isAsking ? "Thinking…" : "Ask", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.school.accentColor)
                .disabled(isAsking || (homeworkQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && homeworkImageData == nil))

                if let askError {
                    Text(askError).font(.caption).foregroundStyle(Color(hex: "FF6B6B"))
                }

                if let homeworkAnswer {
                    Divider().overlay(Theme.cardBorder)
                    Text(homeworkAnswer)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
        .onChange(of: homeworkPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    homeworkImageData = UIImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                }
            }
        }
    }

    private func askForHelp() {
        isAsking = true
        askError = nil
        homeworkAnswer = nil
        let question = homeworkQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = question.isEmpty ? "Explain what's shown in this photo and walk me through how to solve it, step by step." : question
        let image = homeworkImageData

        Task {
            do {
                let answer = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: image,
                    systemPrompt: "You are a patient, encouraging tutor. Explain concepts step by step so the student actually understands the reasoning, not just the answer. Keep it focused and not overly long."
                )
                homeworkAnswer = answer
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }
}

#Preview {
    NavigationStack {
        SchoolView()
    }
    .modelContainer(for: [SchoolClass.self, Topic.self, Assignment.self, Exam.self, StudySession.self, QuizSession.self, QuizQuestion.self], inMemory: true)
}
