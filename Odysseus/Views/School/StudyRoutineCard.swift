//
//  StudyRoutineCard.swift
//  Odysseus
//
//  Turns "here's how much time I have and where I'm at" into actual
//  scheduled reminders (via NotificationManager.scheduleStudyRoutine) —
//  shared by March Exams, ACT, and AP Exams prep so each doesn't reimplement
//  the same metrics input + reminder toggle.
//

import SwiftUI

struct StudyRoutineCard: View {
    @Bindable var exam: Exam
    /// What each reminder should name as the focus — weak topics for March
    /// Exams, empty for ACT/AP (their reminders stay generic).
    var focusPoints: [String] = []

    @State private var weeklyMinutesText = ""
    @State private var knowledgeLevel = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STUDY ROUTINE")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Time available")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                    Spacer()
                    TextField("e.g. 120", text: $weeklyMinutesText)
                        .platformKeyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("min/wk")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Current knowledge")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                        Spacer()
                        Text(knowledgeLabel(knowledgeLevel))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                    }
                    Picker("Current knowledge", selection: $knowledgeLevel) {
                        ForEach(1...5, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    save()
                } label: {
                    Label(exam.routineActive ? "Reminders Active — Update" : "Set Reminders", systemImage: exam.routineActive ? "bell.fill" : "bell.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.school.accentColor)
                .disabled(Int(weeklyMinutesText) == nil)

                if exam.routineActive {
                    Button("Turn off reminders", role: .destructive) {
                        exam.weeklyStudyMinutes = nil
                        exam.routineActive = false
                        NotificationManager.shared.cancelStudyRoutine(exam: exam)
                    }
                    .font(.caption)
                }

                Text("Schedules real reminders between now and \(exam.examDate.formatted(.dateTime.month(.abbreviated).day())), paced to the time you have.")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
        .onAppear {
            weeklyMinutesText = exam.weeklyStudyMinutes.map(String.init) ?? ""
            knowledgeLevel = exam.selfRatedKnowledge ?? 3
        }
    }

    private func knowledgeLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Just starting"
        case 2: return "Some familiarity"
        case 3: return "Comfortable"
        case 4: return "Strong"
        default: return "Feeling solid"
        }
    }

    private func save() {
        guard let minutes = Int(weeklyMinutesText) else { return }
        exam.weeklyStudyMinutes = minutes
        exam.selfRatedKnowledge = knowledgeLevel
        exam.routineActive = true
        NotificationManager.shared.scheduleStudyRoutine(exam: exam, focusPoints: focusPoints)
    }
}
