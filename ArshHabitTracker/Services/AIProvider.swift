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
enum AISettings {
    private static let providerKey = "ai_provider"
    private static let claudeModelKey = "ai_claude_model"
    private static let openAIModelKey = "ai_openai_model"

    static let claudeModelOptions = ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"]
    static let openAIModelOptions = ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "o3-mini"]

    static var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .claude }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static var claudeModel: String {
        get { UserDefaults.standard.string(forKey: claudeModelKey) ?? claudeModelOptions[0] }
        set { UserDefaults.standard.set(newValue, forKey: claudeModelKey) }
    }

    static var openAIModel: String {
        get { UserDefaults.standard.string(forKey: openAIModelKey) ?? openAIModelOptions[0] }
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
