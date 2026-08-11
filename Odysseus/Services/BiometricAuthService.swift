//
//  BiometricAuthService.swift
//  Odysseus
//
//  Wraps LocalAuthentication for the app lock screen. Whatever biometry the
//  device actually has — Face ID on iPhone, Touch ID on Mac/iPad — this asks
//  the OS which one it is rather than assuming per platform, since an iPad
//  or Mac can ship with either depending on the model.
//

import Foundation
import LocalAuthentication

nonisolated final class BiometricAuthService {
    static let shared = BiometricAuthService()

    private init() {}

    enum Kind {
        case touchID, faceID, opticID

        var label: String {
            switch self {
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }

        var systemImage: String {
            switch self {
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }
    }

    /// What kind of biometry this device offers, without prompting for it —
    /// used to pick "Face ID" vs "Touch ID" copy and to decide whether to
    /// show the option at all. `nil` means nothing's enrolled or available
    /// (no hardware, Settings > Face ID/Touch ID never set up, etc).
    var availableKind: Kind? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        switch context.biometryType {
        case .touchID: return .touchID
        case .faceID: return .faceID
        case .opticID: return .opticID
        default: return nil
        }
    }

    /// Prompts Face ID / Touch ID and returns true only on a successful
    /// biometric match. Cancellation, lockout, "no biometry enrolled", and
    /// any other failure all just return false — the caller falls back to
    /// the PIN pad without needing to distinguish why.
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        // This app locks with a PIN pad, not the device passcode, so hide
        // LocalAuthentication's own "Enter Password" fallback button.
        context.localizedFallbackTitle = ""
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}
