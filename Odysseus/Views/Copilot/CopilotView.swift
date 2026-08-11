//
//  CopilotView.swift
//  Odysseus
//

import SwiftUI
import SwiftData
import PhotosUI

struct CopilotView: View {
    @EnvironmentObject private var odysseus: OdysseusController
    @Environment(\.modelContext) private var modelContext

    @State private var showingAPIKeySheet = false
    @State private var showingHistory = false
    @State private var activeSession: ChatSession?

    var body: some View {
        VStack(spacing: 0) {
            odysseusBanner
            if let suggestion = odysseus.latestSuggestion {
                suggestionBanner(suggestion)
            }

            if let activeSession {
                ChatThreadView(session: activeSession)
                    .id(activeSession.id)
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Copilot")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 18) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    Button {
                        activeSession = odysseus.startNewSession(context: modelContext)
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
        .sheet(isPresented: $showingHistory) {
            ChatHistoryView { session in
                odysseus.activeSessionID = session.id
                activeSession = session
            }
        }
        .task {
            if activeSession == nil {
                activeSession = resolveSession()
            }
        }
        .onChange(of: odysseus.activeSessionID) { _, newValue in
            guard let newValue, newValue != activeSession?.id else { return }
            activeSession = try? modelContext.fetch(
                FetchDescriptor<ChatSession>(predicate: #Predicate { $0.id == newValue })
            ).first
        }
    }

    private func resolveSession() -> ChatSession {
        if let id = odysseus.activeSessionID,
           let existing = try? modelContext.fetch(FetchDescriptor<ChatSession>(predicate: #Predicate { $0.id == id })).first {
            return existing
        }
        return odysseus.startNewSession(context: modelContext)
    }

    private var odysseusBanner: some View {
        Button {
            odysseus.activate()
        } label: {
            HStack(spacing: 10) {
                ArcReactorView(size: 28, isActive: odysseus.isActive)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ODYSSEUS MODE")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.primaryText)
                    Text(odysseus.isActive ? "Listening across the app — tap to open" : "Hands-free voice — tap to activate")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(12)
            .background(Theme.card)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
    }

    private func suggestionBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Theme.terminalAmber)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.dimText)
            Spacer()
            Button {
                odysseus.refreshDailySuggestion()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Theme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
    }
}

/// The actual message list + composer for one session — a separate view (not
/// inline in CopilotView) so its @Query can be keyed to a specific session
/// via its initializer; the parent forces a fresh instance per session with
/// .id(session.id) whenever the active thread switches.
private struct ChatThreadView: View {
    let session: ChatSession
    @EnvironmentObject private var odysseus: OdysseusController
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [ChatMessage]

    @State private var draft = ""
    @State private var showingAPIKeySheet = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?

    private var isSending: Bool { odysseus.status == .thinking }
    /// True only in the sliver of time before the first token of a reply has
    /// streamed in — once text starts arriving the growing bubble itself is
    /// the "it's working" signal, so the separate spinner should disappear.
    private var isAwaitingFirstToken: Bool {
        isSending && (messages.last?.role != "assistant" || messages.last?.content.isEmpty == true)
    }

    init(session: ChatSession) {
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
                            emptyState
                        }

                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let isLastAssistant = message.role == "assistant" && index == messages.count - 1
                            ChatBubble(
                                message: message,
                                isStreaming: isLastAssistant && isSending,
                                onCopy: { Pasteboard.copy(message.content) },
                                onDelete: { modelContext.delete(message) },
                                onRetry: isLastAssistant && !isSending ? { odysseus.regenerateLastResponse(session: session, context: modelContext) } : nil
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }

                        if isAwaitingFirstToken {
                            HStack(spacing: 6) {
                                ProgressView().tint(Theme.dimText)
                                Text("Thinking…").font(.caption).foregroundStyle(Theme.dimText)
                            }
                            .padding(.leading, 4)
                            .id("thinking")
                        }

                        if let message = odysseus.statusMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(Theme.negative)
                        }
                    }
                    .padding(12)
                    .animation(.easeOut(duration: 0.2), value: messages.count)
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Theme.dimText.opacity(0.6))
            Text("Ask me to check your status, log a skill session, add a project task, catch you up on the news, or send a coding task to Claude Code/Codex. Or go hands-free with Odysseus mode above.")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isAwaitingFirstToken {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            pendingImagePreview
            composerRow
        }
        .padding(12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
        .task(id: selectedPhoto) {
            await loadPendingImage()
        }
    }

    @ViewBuilder
    private var pendingImagePreview: some View {
        if let pendingImageData, let uiImage = PlatformImage(data: pendingImageData) {
            HStack {
                Image(platformImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                Spacer()
                Button {
                    self.pendingImageData = nil
                    selectedPhoto = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.dimText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var composerRow: some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
            .disabled(isSending)

            TextField("Message Copilot", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassPanel(cornerRadius: 10, tint: Theme.background)
                .onSubmit {
                    guard canSend else { return }
                    send()
                }

            sendOrStopButton
        }
    }

    private var sendOrStopButton: some View {
        Button {
            if isSending {
                odysseus.stopGenerating()
            } else {
                send()
            }
        } label: {
            Image(systemName: isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(isSending ? Theme.negative : (canSend ? Theme.accent : Theme.dimText))
        }
        .buttonStyle(.plain)
        .disabled(!isSending && !canSend)
    }

    private func loadPendingImage() async {
        guard let selectedPhoto else { return }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else { return }
            pendingImageData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
        } catch {
            // No usable image data — leave pendingImageData untouched.
        }
    }

    private var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingImageData != nil) && !isSending
    }

    private func send() {
        var trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || pendingImageData != nil else { return }
        if trimmed.isEmpty { trimmed = "What's in this photo?" }
        guard AISettings.hasActiveKey else {
            showingAPIKeySheet = true
            return
        }
        let imageData = pendingImageData
        draft = ""
        pendingImageData = nil
        selectedPhoto = nil
        odysseus.send(trimmed, imageData: imageData)
    }
}

#Preview {
    NavigationStack {
        CopilotView()
    }
    .environmentObject(OdysseusController.shared)
    .modelContainer(
        for: [ChatMessage.self, ChatSession.self, NewsItem.self, Skill.self, SkillSession.self, Project.self, ProjectTask.self],
        inMemory: true
    )
}
