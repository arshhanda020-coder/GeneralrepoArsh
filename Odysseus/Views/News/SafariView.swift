//
//  SafariView.swift
//  Odysseus
//
//  In-app browser sheet. SFSafariViewController is iOS-only, so this wraps
//  WKWebView directly instead — that gets us the same "open this link
//  without leaving the app" behavior on both iPhone/iPad and Mac.
//

import SwiftUI
import WebKit

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#if os(iOS)
struct SafariView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}
#else
struct SafariView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}
#endif
