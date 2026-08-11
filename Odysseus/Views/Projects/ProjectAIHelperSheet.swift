//
//  ProjectAIHelperSheet.swift
//  Odysseus
//
//  A quick "ask AI" consult for one project — the place to settle "should I
//  do X or Y" questions using this project's own plan/tasks as context,
//  without leaving the project screen for the general Copilot chat.
//

import SwiftUI

struct ProjectAIHelperSheet: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var askError: String?

    private var accentColor: Color { Color(hex: project.colorHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ask about \(project.name) — a design choice, which approach to take, anything you're stuck deciding on. Uses this project's plan and tasks as context.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)

                    TextField("What are you deciding between?", text: $question, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(10)
                        .glassPanel(cornerRadius: 8)
                        .onSubmit {
                            guard !isAsking, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            ask()
                        }

                    Button {
                        ask()
                    } label: {
                        Label(isAsking ? "Thinking…" : "Ask", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .disabled(isAsking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let askError {
                        Text(askError).font(.caption).foregroundStyle(Theme.negative)
                    }
                    if let answer {
                        Divider().overlay(Theme.cardBorder)
                        Text(answer)
                            .font(.subheadline)
                            .foregroundStyle(Theme.primaryText)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("AI Helper")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func ask() {
        isAsking = true
        askError = nil
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskList = project.tasks.sorted { $0.sortIndex < $1.sortIndex }
            .map { "- [\($0.isDone ? "x" : " ")] \($0.title)" }
            .joined(separator: "\n")
        let prompt = """
        Project: \(project.name)
        Description: \(project.projectDescription.isEmpty ? "none" : project.projectDescription)
        Plan: \(project.planText?.isEmpty == false ? project.planText! : "none")
        Tasks:
        \(taskList.isEmpty ? "none yet" : taskList)

        Question: \(trimmed)
        """
        Task {
            do {
                answer = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
                    systemPrompt: "You are a sharp, practical engineering/product advisor helping decide between approaches on a personal project. Give a clear recommendation with brief reasoning, not just a list of options."
                )
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }
}
