//
//  CrossPlatform.swift
//  Odysseus
//
//  Small shims for the handful of SwiftUI/Foundation APIs that are
//  iOS-only (no macOS counterpart, or a differently-shaped one) but get
//  used from views shared between the iOS and macOS targets.
//

import SwiftUI

extension View {
    /// `.navigationBarTitleDisplayMode(.inline)` only exists on iOS/iPadOS —
    /// macOS's title bar has no large/inline distinction, so this is a no-op there.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// `fullScreenCover` doesn't exist on macOS (there's no modal "cover the
    /// whole screen" concept for a windowed app) — falls back to `.sheet`,
    /// which is the closest native equivalent for a modal flow.
    @ViewBuilder
    func platformFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }

    @ViewBuilder
    func platformFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, content: content)
        #else
        self.sheet(item: item, content: content)
        #endif
    }

    /// The `.zoom` navigation transition style is iOS/iPadOS-only in this
    /// SDK — macOS has no full-screen push/zoom transition model for
    /// NavigationStack, so this just falls back to the default transition there.
    @ViewBuilder
    func zoomNavigationTransition<ID: Hashable>(sourceID: ID, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        #else
        self
        #endif
    }
}

enum PlatformAutocapitalization {
    case never, words, characters

    #if os(iOS)
    var textInputStyle: TextInputAutocapitalization {
        switch self {
        case .never: .never
        case .words: .words
        case .characters: .characters
        }
    }
    #endif
}

extension View {
    /// `.textInputAutocapitalization` is iOS/iPadOS-only — macOS text fields
    /// don't auto-capitalize at all, so this is a no-op there.
    @ViewBuilder
    func platformAutocapitalization(_ style: PlatformAutocapitalization) -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(style.textInputStyle)
        #else
        self
        #endif
    }
}

enum PlatformKeyboardType {
    case numberPad, decimalPad, emailAddress, url

    #if os(iOS)
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .numberPad: .numberPad
        case .decimalPad: .decimalPad
        case .emailAddress: .emailAddress
        case .url: .URL
        }
    }
    #endif
}

extension View {
    /// `.keyboardType` is iOS/iPadOS-only — there's no on-screen keyboard to
    /// configure on macOS, so this is a no-op there.
    @ViewBuilder
    func platformKeyboardType(_ type: PlatformKeyboardType) -> some View {
        #if os(iOS)
        self.keyboardType(type.uiKeyboardType)
        #else
        self
        #endif
    }
}

enum Pasteboard {
    /// UIPasteboard on iOS, NSPasteboard on macOS.
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #endif
    }
}
