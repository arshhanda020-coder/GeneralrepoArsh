//
//  SectionAssistantView.swift
//  Odysseus
//
//  A small AI chat scoped to one section (School, Health, Projects, …) —
//  same chat plumbing as Copilot (ChatSession/ChatMessage, streamed replies,
//  the active provider from AISettings) but its own persisted thread per
//  section and a system prompt built fresh per message from that section's
//  own live data (see SectionAssistantPrompt). No tool use: this assistant
//  answers and advises, it doesn't act on your data — Copilot remains the
//  one place for that.
//

import SwiftUI
import SwiftData

/// Adds a toolbar button that opens `section`'s AI assistant as a sheet.
/// Drop this onto any section's root view: `.sectionAssistantButton(.school)`.
struct SectionAssistantButtonModifier: ViewModifier {
    let section: MindMapSection
    @State private var showingAssistant = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAssistant = true
                    } label: {
                        Image(systemName: "text.bubble.fill")
                    }
                    .accessibilityLabel("\(section.title) Assistant")
                }
            }
            .sheet(isPresented: $showingAssistant) {
                SectionAssistantView(section: section)
            }
    }
}

extension View {
    func sectionAssistantButton(_ section: MindMapSection) -> some View {
        modifier(SectionAssistantButtonModifier(section: section))
    }
}

struct SectionAssistantView: View {
    let section: MindMapSection

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage private var storedSessionID: String?

    @State private var session: ChatSession?
    @State private var showingAPIKeySheet = false

    init(section: MindMapSection) {
        self.section = section
        self._storedSessionID = AppStorage("section_chat_session_\(section.rawValue)")
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    SectionChatThreadView(section: section, session: session)
                        .id(session.id)
                } else {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("\(section.title) Assistant")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 14) {
                        Button {
                            startNewChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        Button {
                            showingAPIKeySheet = true
                        } label: {
                            Image(systemName: "key")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeySheet()
            }
            .task {
                if session == nil {
                    session = resolveSession()
                }
            }
        }
    }

    private func resolveSession() -> ChatSession {
        if let id = storedSessionID,
           let existing = try? modelContext.fetch(FetchDescriptor<ChatSession>(predicate: #Predicate { $0.id == id })).first {
            return existing
        }
        return makeNewSession()
    }

    private func startNewChat() {
        session = makeNewSession()
    }

    @discardableResult
    private func makeNewSession() -> ChatSession {
        let newSession = ChatSession(title: "\(section.title) Assistant", sectionKey: section.rawValue)
        modelContext.insert(newSession)
        storedSessionID = newSession.id
        return newSession
    }
}

/// The message list + composer for one section thread — a separate view (not
/// inline in SectionAssistantView) so its @Query can be keyed to a specific
/// session via its initializer, same pattern as Copilot's ChatThreadView.
private struct SectionChatThreadView: View {
    let section: MindMapSection
    let session: ChatSession
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [ChatMessage]

    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showingAPIKeySheet = false

    init(section: MindMapSection, session: ChatSession) {
        self.section = section
        self.session = session
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
                            Text(SectionAssistantPrompt.openingHint(for: section))
                                .font(.subheadline)
                                .foregroundStyle(Theme.dimText)
                                .padding(.top, 40)
                        }

                        ForEach(messages) { message in
                            SectionChatBubble(message: message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack(spacing: 6) {
                                ProgressView().tint(Theme.dimText)
                                Text("Thinking…").font(.caption).foregroundStyle(Theme.dimText)
                            }
                            .padding(.leading, 4)
                            .id("thinking")
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Theme.negative)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { scrollToBottom(proxy) }
                .onChange(of: isSending) { scrollToBottom(proxy) }
            }

            inputBar
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySheet()
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isSending {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about \(section.title)", text: $draft, axis: .vertical)
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
                    .foregroundStyle(canSend ? section.accentColor : Theme.dimText)
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
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard AISettings.hasActiveKey else {
            showingAPIKeySheet = true
            return
        }
        draft = ""
        Task { await sendMessage(trimmed) }
    }

    private func sendMessage(_ text: String) async {
        errorMessage = nil
        isSending = true
        defer { isSending = false }

        let userMessage = ChatMessage(role: "user", content: text, session: session)
        modelContext.insert(userMessage)
        session.lastActivityAt = .now

        let sessionID = session.id
        let history = (try? modelContext.fetch(
            FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.session?.id == sessionID },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        )) ?? []

        // Inserted empty and filled in live as tokens stream — same reasoning
        // as Copilot's ChatThreadView: the reply appears word-by-word instead
        // of all at once after a long silent wait.
        let assistantMessage = ChatMessage(role: "assistant", content: "", session: session)
        modelContext.insert(assistantMessage)

        do {
            let systemPrompt = SectionAssistantPrompt.systemPrompt(for: section, modelContext: modelContext)
            let reply = try await AISettings.currentService.sendSectionChat(
                history: history,
                systemPrompt: systemPrompt,
                onTextDelta: { delta in assistantMessage.content += delta }
            )
            assistantMessage.content = reply
        } catch {
            modelContext.delete(assistantMessage)
            errorMessage = error.localizedDescription
        }
    }
}

private struct SectionChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
                .padding(10)
                .background(isUser ? Theme.accent.opacity(0.25) : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
