//
//  AIProvider.swift
//  ArshHabitTracker
//

import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case claude
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "ChatGPT"
        }
    }
}

/// Every AI feature in the app (Copilot, Jarvis, Test Me, homework help, email
/// drafting, macro estimation) goes through whichever provider/model is
/// currently selected here, rather than being hardcoded to one service.
nonisolated enum AISettings {
    private static let providerKey = "ai_provider"
    private static let claudeModelKey = "ai_claude_model"
    private static let openAIModelKey = "ai_openai_model"

    // Ordered best-balance-first — this is also the display order in the
    // dropdown, so the recommended default is what a user sees at the top.
    static let claudeModelOptions = ["claude-sonnet-5", "claude-opus-5", "claude-haiku-4-5"]
    static let openAIModelOptions = ["gpt-4o", "gpt-4.1", "gpt-4o-mini", "o3-mini"]

    /// Sonnet balances answer quality against cost/usage well for everyday
    /// in-app features (chat, quizzes, drafts) — Opus and Haiku stay one tap
    /// away in the dropdown for anyone who wants max quality or max savings.
    private static let recommendedClaudeModel = "claude-sonnet-5"
    private static let recommendedOpenAIModel = "gpt-4o"

    static var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .claude }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static var claudeModel: String {
        get { UserDefaults.standard.string(forKey: claudeModelKey) ?? recommendedClaudeModel }
        set { UserDefaults.standard.set(newValue, forKey: claudeModelKey) }
    }

    static var openAIModel: String {
        get { UserDefaults.standard.string(forKey: openAIModelKey) ?? recommendedOpenAIModel }
        set { UserDefaults.standard.set(newValue, forKey: openAIModelKey) }
    }

    static var currentService: any AIProviderService {
        switch provider {
        case .claude: return AnthropicService.shared
        case .openai: return OpenAIService.shared
        }
    }

    /// Whether the *active* provider has a key configured — checking the
    /// wrong provider's key here was a real bug (blocked ChatGPT even with a
    /// valid key, if Claude's key was unset).
    static var hasActiveKey: Bool {
        switch provider {
        case .claude: return KeychainService.shared.loadAPIKey() != nil
        case .openai: return KeychainService.shared.loadOpenAIKey() != nil
        }
    }
}
