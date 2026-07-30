//
//  GmailAuthManager.swift
//  ArshHabitTracker
//
//  OAuth 2.0 (Authorization Code + PKCE) sign-in for Gmail send access.
//  Requires a Google Cloud OAuth client ID the user creates themselves — see
//  GmailSettingsSheet for the one-time setup instructions.
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class GmailAuthManager: NSObject, ObservableObject {
    static let shared = GmailAuthManager()

    @Published var isConnected = false
    @Published var statusMessage: String?

    private var session: ASWebAuthenticationSession?
    private var codeVerifier: String?

    private override init() {
        super.init()
        isConnected = KeychainService.shared.loadGmailRefreshToken() != nil
    }

    private var clientID: String? { KeychainService.shared.loadGmailClientID() }

    /// Google's convention for "iOS" OAuth clients: a custom URL scheme built
    /// from the numeric prefix of the client ID. Must match a URL Type added
    /// in the Xcode target's Info settings (see GmailSettingsSheet).
    var redirectURI: String? {
        guard let clientID, let prefix = clientID.split(separator: "-").first, !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix):/oauth2redirect"
    }

    func connect() {
        guard let clientID, !clientID.isEmpty else {
            statusMessage = "Add your Google OAuth client ID in Emails settings first."
            return
        }
        guard let redirectURI, let scheme = redirectURI.split(separator: ":").first.map(String.init) else {
            statusMessage = "That client ID doesn't look right — check it in Emails settings."
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
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/gmail.send"),
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
        KeychainService.shared.deleteGmailRefreshToken()
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
                KeychainService.shared.saveGmailRefreshToken(refreshToken)
            }
            if let accessToken = json["access_token"] as? String {
                KeychainService.shared.saveGmailAccessToken(accessToken, expiresIn: json["expires_in"] as? Int ?? 3600)
            }
            isConnected = KeychainService.shared.loadGmailRefreshToken() != nil
            if !isConnected {
                statusMessage = "Google didn't return a refresh token. Disconnect and try again."
            }
        } catch {
            statusMessage = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    /// Returns a live access token, refreshing via the stored refresh token if needed.
    func validAccessToken() async -> String? {
        if let token = KeychainService.shared.loadGmailAccessTokenIfValid() {
            return token
        }
        guard let clientID, let refreshToken = KeychainService.shared.loadGmailRefreshToken() else { return nil }
        let params: [String: String] = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        guard let json = try? await Self.postForm(to: "https://oauth2.googleapis.com/token", params: params),
              let accessToken = json["access_token"] as? String else { return nil }
        KeychainService.shared.saveGmailAccessToken(accessToken, expiresIn: json["expires_in"] as? Int ?? 3600)
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

extension GmailAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
