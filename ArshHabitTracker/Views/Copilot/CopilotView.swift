//
//  CopilotView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData
import PhotosUI

struct CopilotView: View {
    @EnvironmentObject private var jarvis: JarvisController
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]

    @State private var draft = ""
    @State private var showingAPIKeySheet = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?

    private var isSending: Bool { jarvis.status == .thinking }

    var body: some View {
        VStack(spacing: 0) {
            jarvisBanner
            if let suggestion = jarvis.latestSuggestion {
                suggestionBanner(suggestion)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            Text("Ask me to check your status, mark a habit done, log a skill session, add a project task, or catch you up on the news. Or go hands-free with Jarvis mode above.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.dimText)
                                .padding(.top, 40)
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message)
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

                        if let message = jarvis.statusMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "FF6B6B"))
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { scrollToBottom(proxy) }
                .onChange(of: isSending) { scrollToBottom(proxy) }
            }

            inputBar
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Copilot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAPIKeySheet = true
                } label: {
                    Image(systemName: "key")
                }
            }
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeySheet()
        }
    }

    private var jarvisBanner: some View {
        Button {
            jarvis.activate()
        } label: {
            HStack(spacing: 10) {
                ArcReactorView(size: 28, isActive: jarvis.isActive)
                VStack(alignment: .leading, spacing: 1) {
                    Text("JARVIS MODE")
                        .font(.caption.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                    Text(jarvis.isActive ? "Listening across the app — tap to open" : "Hands-free voice — tap to activate")
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
                jarvis.refreshDailySuggestion()
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
        VStack(spacing: 8) {
            if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                HStack {
                    Image(uiImage: uiImage)
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

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Theme.dimText)
                }
                .buttonStyle(.plain)

                TextField("Message Copilot", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? Color(hex: "5B8CFF") : Theme.dimText)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(12)
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    pendingImageData = UIImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                }
            }
        }
    }

    private var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingImageData != nil) && !isSending
    }

    private func send() {
        var trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || pendingImageData != nil else { return }
        if trimmed.isEmpty { trimmed = "What's in this photo?" }
        guard KeychainService.shared.loadAPIKey() != nil else {
            showingAPIKeySheet = true
            return
        }
        let imageData = pendingImageData
        draft = ""
        pendingImageData = nil
        selectedPhoto = nil
        Task { await jarvis.sendMessage(trimmed, imageData: imageData) }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(10)
            .background(isUser ? Color(hex: "5B8CFF").opacity(0.25) : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        CopilotView()
    }
    .environmentObject(JarvisController.shared)
    .modelContainer(
        for: [ChatMessage.self, NewsItem.self, Habit.self, Completion.self, Skill.self, SkillSession.self, Project.self, ProjectTask.self],
        inMemory: true
    )
}
