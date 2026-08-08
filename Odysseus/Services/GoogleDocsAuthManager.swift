//
//  GoogleDocsAuthManager.swift
//  Odysseus
//
//  OAuth 2.0 (Authorization Code + PKCE) sign-in for read-only Google Docs
//  access. Reuses the same Google Cloud OAuth client ID as Gmail (Settings ->
//  Emails already walks through creating one) — it's the same Google Cloud
//  project, just a wider scope grant — but keeps a separate token pair since
//  it's a distinct consent from Gmail send access. Requires the Google Drive
//  API and Google Docs API enabled on that Cloud project.
//

import Foundation
import Combine
import AuthenticationServices
import CryptoKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class GoogleDocsAuthManager: NSObject, ObservableObject {
    static let shared = GoogleDocsAuthManager()

    @Published var isConnected = false
    @Published var statusMessage: String?

    private var session: ASWebAuthenticationSession?
    private var codeVerifier: String?

    private override init() {
        super.init()
        isConnected = KeychainService.shared.loadGoogleDocsRefreshToken() != nil
    }

    private var clientID: String? { KeychainService.shared.loadGmailClientID() }

    /// Same derivation as GmailAuthManager — Google's "iOS" OAuth client
    /// convention. The URL Type only needs adding once; if Gmail is already
    /// wired up in this Xcode target, Docs reuses the same redirect scheme.
    var redirectURI: String? {
        guard let clientID, let prefix = clientID.split(separator: "-").first, !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix):/oauth2redirect"
    }

    func connect() {
        guard let clientID, !clientID.isEmpty else {
            statusMessage = "Add your Google OAuth client ID in Notes settings first."
            return
        }
        guard let redirectURI, let scheme = redirectURI.split(separator: ":").first.map(String.init) else {
            statusMessage = "That client ID doesn't look right — check it in Notes settings."
            return
        }

        let verifier = Self.randomURLSafeString(length: 64)
        codeVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/documents.readonly"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authURL = components.url else { return }

        statusMessage = nil
        session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] callbackURL, error in
            guard let self else { return }
            Task { @MainActor in
                await self.handleCallback(callbackURL, error: error, clientID: clientID, redirectURI: redirectURI)
            }
        }
        session?.presentationContextProvider = self
        session?.prefersEphemeralWebBrowserSession = false
        session?.start()
    }

    func disconnect() {
        KeychainService.shared.deleteGoogleDocsRefreshToken()
        isConnected = false
    }

    private func handleCallback(_ callbackURL: URL?, error: Error?, clientID: String, redirectURI: String) async {
        if let error {
            let nsError = error as NSError
            if nsError.domain == ASWebAuthenticationSessionErrorDomain,
               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            statusMessage = "Sign-in failed: \(error.localizedDescription)"
            return
        }
        guard let callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else {
            statusMessage = "Didn't receive an authorization code from Google."
            return
        }
        await exchangeCode(code, clientID: clientID, redirectURI: redirectURI)
    }

    private func exchangeCode(_ code: String, clientID: String, redirectURI: String) async {
        guard let verifier = codeVerifier else { return }
        let params: [String: String] = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ]

        do {
            let json = try await Self.postForm(to: "https://oauth2.googleapis.com/token", params: params)
            if let refreshToken = json["refresh_token"] as? String {
                KeychainService.shared.saveGoogleDocsRefreshToken(refreshToken)
            }
            if let accessToken = json["access_token"] as? String {
                KeychainService.shared.saveGoogleDocsAccessToken(accessToken, expiresIn: json["expires_in"] as? Int ?? 3600)
            }
            let connected = KeychainService.shared.loadGoogleDocsRefreshToken() != nil
            isConnected = connected
            if !connected {
                statusMessage = "Google didn't return a refresh token. Disconnect and try again."
            }
        } catch {
            statusMessage = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    /// Returns a live access token, refreshing via the stored refresh token if needed.
    func validAccessToken() async -> String? {
        if let token = KeychainService.shared.loadGoogleDocsAccessTokenIfValid() {
            return token
        }
        guard let clientID, let refreshToken = KeychainService.shared.loadGoogleDocsRefreshToken() else { return nil }
        let params: [String: String] = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        guard let json = try? await Self.postForm(to: "https://oauth2.googleapis.com/token", params: params),
              let accessToken = json["access_token"] as? String else { return nil }
        KeychainService.shared.saveGoogleDocsAccessToken(accessToken, expiresIn: json["expires_in"] as? Int ?? 3600)
        return accessToken
    }

    private static func postForm(to urlString: String, params: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = Data(body.utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func randomURLSafeString(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension GoogleDocsAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #elseif canImport(AppKit)
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #endif
    }
}
