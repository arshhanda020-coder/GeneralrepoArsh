//
//  NewsItemDetailView.swift
//  ArshHabitTracker
//
//  Tapping a headline shows the link itself (copyable, open-in-Safari is
//  opt-in) instead of jumping straight to the site, plus an "Inquiries" box
//  to ask AI about the article.
//

import SwiftUI

struct NewsItemDetailView: View {
    let item: NewsItem

    @State private var safariURL: IdentifiableURL?
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var askError: String?
    @State private var didCopy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.source.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.3)
                        .foregroundStyle(Theme.accent)
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    if let snippet = item.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.subheadline)
                            .foregroundStyle(Theme.dimText)
                    }
                }

                linkSection
                inquirySection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LINK")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            Text(item.link)
                .font(.caption)
                .foregroundStyle(Theme.primaryText)
                .lineLimit(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = item.link
                    didCopy = true
                } label: {
                    Label(didCopy ? "Copied" : "Copy Link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)

                Button {
                    if let url = URL(string: item.link) {
                        safariURL = IdentifiableURL(url: url)
                    }
                } label: {
                    Label("Open", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var inquirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INQUIRIES")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Ask AI something about this article", text: $question, axis: .vertical)
                    .lineLimit(1...4)

                Button {
                    ask()
                } label: {
                    Label(isAsking ? "Thinking…" : "Ask", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(isAsking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let askError {
                    Text(askError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                }
                if let answer {
                    Divider().overlay(Theme.cardBorder)
                    Text(answer).font(.caption).foregroundStyle(Theme.primaryText)
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private func ask() {
        isAsking = true
        askError = nil
        let prompt = """
        A news article: "\(item.title)" from \(item.source).
        Snippet: \(item.snippet ?? "none")
        Question about this article: \(question)
        """
        Task {
            do {
                answer = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
                    systemPrompt: "You are a sharp, concise news analyst. Answer the user's question about the article using the title/snippet given — note plainly if you'd need the full article to be certain."
                )
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }
}

#Preview {
    NavigationStack {
        NewsItemDetailView(item: NewsItem(id: "1", title: "Sample", link: "https://example.com", source: "Example", publishedAt: .now, snippet: "A snippet.", topic: .ai))
    }
}
