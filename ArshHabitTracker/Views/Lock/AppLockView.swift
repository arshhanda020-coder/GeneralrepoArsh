//
//  AppLockView.swift
//  ArshHabitTracker
//
//  Local device lock only — a 4-digit PIN stored in Keychain, checked on
//  every cold launch. Not an account/auth system; there's no server to
//  authenticate against.
//

import SwiftUI

struct AppLockView: View {
    var onUnlocked: () -> Void

    @State private var hasPIN = KeychainService.shared.loadPIN() != nil
    @State private var entered = ""
    @State private var confirmStage = false
    @State private var firstEntry = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)

            Text(hasPIN ? "Enter PIN" : (confirmStage ? "Confirm PIN" : "Create a PIN"))
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
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "C0605C"))
            }

            Spacer()

            keypad
                .padding(.bottom, 40)
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

        if hasPIN {
            if KeychainService.shared.loadPIN() == entered {
                onUnlocked()
            } else {
                errorMessage = "Incorrect PIN."
                entered = ""
            }
        } else if !confirmStage {
            firstEntry = entered
            entered = ""
            confirmStage = true
        } else {
            if entered == firstEntry {
                KeychainService.shared.savePIN(entered)
                onUnlocked()
            } else {
                errorMessage = "PINs didn't match — try again."
                entered = ""
                confirmStage = false
                firstEntry = ""
            }
        }
    }
}

#Preview {
    AppLockView(onUnlocked: {})
}
