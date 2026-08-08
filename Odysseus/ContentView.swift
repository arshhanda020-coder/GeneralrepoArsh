//
//  ContentView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            MindMapHomeView()
        }
        .tint(Theme.accent)
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                FoodEntry.self, WorkoutEntry.self,
                Skill.self, SkillSession.self,
                Project.self, ProjectTask.self,
                NewsItem.self, ChatMessage.self, ChatSession.self,
                AIToolItem.self, Exam.self, StudySession.self,
                Assignment.self, QuizSession.self, QuizQuestion.self,
            ],
            inMemory: true
        )
}
