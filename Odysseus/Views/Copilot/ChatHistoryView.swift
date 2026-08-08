//
//  ChatHistoryView.swift
//  Odysseus
//
//  Every chat thread ever started, newest first — nothing here is ever
//  auto-deleted. Tap one to make it the active thread in Copilot.
//

import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    let onSelect: (ChatSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var odysseus: OdysseusController
    @Query(sort: \ChatSession.lastActivityAt, order: .reverse) private var sessions: [ChatSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    Text("No chats yet.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessions) { session in
                            Button {
                                onSelect(session)
                                dismiss()
                            } label: {
                                row(session)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Chat History")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ session: ChatSession) -> some View {
        let isActive = session.id == odysseus.activeSessionID
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isActive ? Theme.accent : Theme.primaryText)
                    .lineLimit(1)
                Text("\(session.messages.count) message\(session.messages.count == 1 ? "" : "s") · \(relativeTime(session.lastActivityAt))")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            modelContext.delete(session)
            if session.id == odysseus.activeSessionID {
                odysseus.activeSessionID = nil
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
