//
//  TopicAssistantView.swift
//  Odysseus
//
//  A Copilot-style chat scoped to one School topic — same provider/model
//  the user has picked in Settings (Claude or ChatGPT), but it only knows
//  about this topic's own assignments and notes, and can generate/adjust a
//  practice quiz or log a real score instead of Copilot's full tool set.
//  One persistent thread per topic (no "new chat" — see
//  TopicAssistantController.resolveSession).
//

import SwiftUI
import SwiftData

struct TopicAssistantView: View {
    let topic: Topic

    @Environment(\.modelContext) private var modelContext
    @StateObject private var controller = TopicAssistantController()
    @State private var session: ChatSession?

    var body: some View {
        Group {
            if let session {
                ThreadView(topic: topic, session: session, controller: controller)
                    .id(session.id)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Study: \(topic.name)")
        .inlineNavigationTitle()
        .task {
            if session == nil {
                session = controller.resolveSession(for: topic, context: modelContext)
            }
        }
        .platformFullScreenCover(item: $controller.pendingQuizSession) { quizSession in
            QuizSessionView(session: quizSession)
        }
    }
}

/// The message list + composer for the topic's one thread — split out (like
/// Copilot's ChatThreadView) so its @Query can be keyed to the session via init.
private struct ThreadView: View {
    let topic: Topic
    let session: ChatSession
    @ObservedObject var controller: TopicAssistantController

    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [ChatMessage]

    @State private var draft = ""
    @State private var showingAPIKeySheet = false

    init(topic: Topic, session: ChatSession, controller: TopicAssistantController) {
        self.topic = topic
        self.session = session
        self.controller = controller
        let sessionID = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.session?.id == sessionID },
            sort: \ChatMessage.createdAt
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            Text("Ask me anything about \(topic.name) — I can see the assignments and notes you've logged here. I can also test you (\"quiz me\", \"make it harder\") or log a real score you tell me about.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.dimText)
                                .padding(.top, 40)
                        }

                        ForEach(messages) { message in
                            StudyChatBubble(message: message)
                                .id(message.id)
                        }

                        if controller.isSending {
                            HStack(spacing: 6) {
                                ProgressView().tint(Theme.dimText)
                                Text("Thinking…").font(.caption).foregroundStyle(Theme.dimText)
                            }
                            .padding(.leading, 4)
                            .id("thinking")
                        }

                        if let statusMessage = controller.statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(Theme.negative)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { scrollToBottom(proxy) }
                .onChange(of: controller.isSending) { scrollToBottom(proxy) }
            }

            inputBar
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySheet()
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if controller.isSending {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about \(topic.name), or \"quiz me\"…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassPanel(cornerRadius: 10, tint: Theme.background)
                .onSubmit {
                    guard canSend else { return }
                    send()
                }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? MindMapSection.school.accentColor : Theme.dimText)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !controller.isSending
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard AISettings.hasActiveKey else {
            showingAPIKeySheet = true
            return
        }
        draft = ""
        Task { await controller.sendMessage(trimmed, topic: topic, session: session, context: modelContext) }
    }
}

private struct StudyChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
                .padding(10)
                .background(isUser ? MindMapSection.school.accentColor.opacity(0.25) : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        TopicAssistantView(topic: Topic(name: "Recursion"))
    }
    .modelContainer(for: [Topic.self, ChatSession.self, ChatMessage.self, QuizSession.self, QuizQuestion.self, Note.self], inMemory: true)
}
