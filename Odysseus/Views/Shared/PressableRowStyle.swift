//
//  PressableRowStyle.swift
//  Odysseus
//
//  Plain-button rows (.buttonStyle(.plain)) give zero tactile feedback on
//  tap — no highlight, no press state, nothing. This is the missing touch:
//  a small scale + opacity dip while held, spring back on release.
//

import SwiftUI

struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableRowStyle {
    static var pressableRow: PressableRowStyle { PressableRowStyle() }
}
