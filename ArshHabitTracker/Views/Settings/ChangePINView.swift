//
//  ChangePINView.swift
//  ArshHabitTracker
//
//  Three stages so the old PIN is never cleared until a valid new one is
//  confirmed — no risk of getting locked out mid-change.
//

import SwiftUI

struct ChangePINView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case verifyCurrent, enterNew, confirmNew }

    @State private var stage: Stage = .verifyCurrent
    @State private var entered = ""
    @State private var newPINFirstEntry = ""
    @State private var errorMessage: String?

    private var title: String {
        switch stage {
        case .verifyCurrent: return "Enter current PIN"
        case .enterNew: return "Enter new PIN"
        case .confirmNew: return "Confirm new PIN"
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.rotation")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < entered.count ? Theme.accent : Theme.card)
                        .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                        .frame(width: 16, height: 16)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(Color(hex: "C0605C"))
            }

            Spacer()
            keypad.padding(.bottom, 20)

            Button("Cancel") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .padding(.bottom, 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 18) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            handleKey(key)
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                } else {
                    Text(key)
                }
            }
            .font(.title2.weight(.medium))
            .foregroundStyle(.white)
            .frame(width: 68, height: 68)
            .background(key.isEmpty ? Color.clear : Theme.card)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.cardBorder, lineWidth: key.isEmpty ? 0 : 1))
        }
        .buttonStyle(.plain)
        .disabled(key.isEmpty)
    }

    private func handleKey(_ key: String) {
        errorMessage = nil
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < 4 else { return }
        entered.append(key)
        guard entered.count == 4 else { return }

        switch stage {
        case .verifyCurrent:
            if KeychainService.shared.loadPIN() == entered {
                entered = ""
                stage = .enterNew
            } else {
                errorMessage = "Incorrect PIN."
                entered = ""
            }
        case .enterNew:
            newPINFirstEntry = entered
            entered = ""
            stage = .confirmNew
        case .confirmNew:
            if entered == newPINFirstEntry {
                KeychainService.shared.savePIN(entered)
                dismiss()
            } else {
                errorMessage = "PINs didn't match — try again."
                entered = ""
                newPINFirstEntry = ""
                stage = .enterNew
            }
        }
    }
}

#Preview {
    ChangePINView()
}
