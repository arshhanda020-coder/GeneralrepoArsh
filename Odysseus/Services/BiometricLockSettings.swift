//
//  BiometricLockSettings.swift
//  Odysseus
//
//  Just the on/off switch for "skip the PIN pad with Face ID/Touch ID
//  instead" — not a secret itself, so UserDefaults (same pattern as
//  GPASettings) rather than Keychain. The PIN in Keychain stays the
//  underlying credential either way; this only decides whether the lock
//  screen tries biometrics first.
//

import Foundation

nonisolated enum BiometricLockSettings {
    private static let enabledKey = "biometric_unlock_enabled"

    /// Defaults to on so a device with Face ID/Touch ID already enrolled
    /// gets the faster unlock without an extra settings trip — the PIN pad
    /// is still there as a fallback and to reset.
    static var isEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
