//
//  AnthropicService.swift
//  ArshHabitTracker
//
//  Raw HTTP client for the Claude Messages API. There is no official Anthropic
//  Swift SDK, so requests are built and parsed by hand (per Anthropic's own
//  guidance for unsupported languages: use the documented cURL/raw-HTTP shape).
//

import Foundation

/// Copilot can both answer questions and act on the app's data — the tool
/// executor is supplied by the view layer, which owns the SwiftData context.
actor AnthropicService: AIProviderService {
    static let shared = AnthropicService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private var model: String { AISettings.claudeModel }

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your Anthropic API key in Copilot settings (key icon, top right)."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private init() {}

    func send(
        history: [ChatMessage],
        toolExecutor: @escaping (String, [String: Any]) async -> String
    ) async throws -> String {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        var messages: [[String: Any]] = history.map { message in
            var content: [[String: Any]] = []
            if let imageData = message.imageData {
                content.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": imageData.base64EncodedString(),
                    ] as [String: Any],
                ])
            }
            content.append(["type": "text", "text": message.content])
            return ["role": message.role, "content": content]
        }

        for _ in 0..<6 {
            let body: [String: Any] = [
                "model": model,
                "max_tokens": 4096,
                "thinking": ["type": "adaptive"],
                "system": Self.systemPrompt,
                "messages": messages,
                "tools": Self.tools,
            ]

            let (contentBlocks, stopReason) = try await performRequest(body: body, apiKey: apiKey)

            if stopReason == "tool_use" {
                messages.append(["role": "assistant", "content": contentBlocks])

                var toolResults: [[String: Any]] = []
                for block in contentBlocks {
                    guard let type = block["type"] as? String, type == "tool_use",
                          let toolUseId = block["id"] as? String,
                          let name = block["name"] as? String else { continue }
                    let input = block["input"] as? [String: Any] ?? [:]
                    let result = await toolExecutor(name, input)
                    toolResults.append(["type": "tool_result", "tool_use_id": toolUseId, "content": result])
                }
                messages.append(["role": "user", "content": toolResults])
                continue
            }

            let text = contentBlocks
                .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                .joined(separator: "\n")
            return text.isEmpty ? "(no response)" : text
        }

        throw ServiceError.requestFailed("Copilot took too many steps — try again.")
    }

    /// One-shot vision-capable call — used for homework help (School) and food
    /// macro estimation (Food). No tools, no history; image is optional.
    func askAboutImage(prompt: String, imageData: Data?, systemPrompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        var content: [[String: Any]] = []
        if let imageData {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": imageData.base64EncodedString(),
                ] as [String: Any],
            ])
        }
        content.append(["type": "text", "text": prompt])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1200,
            "thinking": ["type": "adaptive"],
            "system": systemPrompt,
            "messages": [["role": "user", "content": content]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return text.isEmpty ? "I couldn't come up with an answer — try rephrasing or a clearer photo." : text
    }

    /// Generates one quiz question + answer for the Test Me feature.
    func generateQuizQuestion(subject: String) async throws -> (question: String, answer: String) {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 600,
            "thinking": ["type": "adaptive"],
            "system": """
            You are a tutor creating one quiz question at a time to test a student's understanding of a topic. \
            Respond in EXACTLY this format, nothing else, no markdown:
            QUESTION: <one specific, answerable question>
            ANSWER: <the correct answer with a brief explanation>
            """,
            "messages": [["role": "user", "content": [["type": "text", "text": "Subject/topic: \(subject)"]]]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return Self.parseQuiz(text)
    }

    private static func parseQuiz(_ text: String) -> (question: String, answer: String) {
        guard let answerRange = text.range(of: "ANSWER:") else {
            let question = text.replacingOccurrences(of: "QUESTION:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (question, "")
        }
        let questionPart = text[text.startIndex..<answerRange.lowerBound]
            .replacingOccurrences(of: "QUESTION:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let answerPart = text[answerRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (questionPart, answerPart)
    }

    /// One-shot draft-writing call — used for email composition. No tools, no history.
    func draft(prompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 800,
            "thinking": ["type": "adaptive"],
            "system": "You write clear, professional email drafts. Return only the email body text — no subject line, no preamble, no markdown.",
            "messages": [["role": "user", "content": [["type": "text", "text": prompt]]]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return text
    }

    /// One-shot, historyless call used for proactive suggestions — not part of the
    /// chat transcript, no tools, just "given this status, what's one good next step."
    func suggestion(for statusContext: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "thinking": ["type": "adaptive"],
            "system": "You are a proactive assistant for ArshHabitTracker, a personal app covering habits, skills, projects, food/macros, workouts, school assignments, and upcoming tests. Given the user's current status across all of that, suggest exactly ONE short, specific, encouraging next action — prioritize anything overdue or due today. One or two sentences, no preamble, no lists.",
            "messages": [["role": "user", "content": [["type": "text", "text": statusContext]]]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return text.isEmpty ? "Check in on today's habits — you've got momentum to keep." : text
    }

    private func performRequest(
        body: [String: Any],
        apiKey: String
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("No response from server.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.requestFailed("Malformed response.")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
                ?? "Request failed (\(http.statusCode))."
            throw ServiceError.requestFailed(message)
        }

        let content = json["content"] as? [[String: Any]] ?? []
        let stopReason = json["stop_reason"] as? String ?? "end_turn"
        return (content, stopReason)
    }

    private static let systemPrompt = """
    You are the in-app copilot for ArshHabitTracker — a personal app for habits, skills, projects, news, and \
    coding projects. You can both answer questions and take actions using your tools: check today's status, \
    mark habits done or not done, log skill practice sessions, add tasks to projects, fetch cached news \
    headlines by topic (finance, accounting, economics, ai, or all), and recall the user's GitHub repositories. \
    When the user asks you to do something ("mark X done", "log a session for Y", "add a task to Z", "what \
    repos do I have"), call the matching tool rather than just describing what you'd do. Be concise — replies \
    may be read aloud.
    """

    private static let tools: [[String: Any]] = [
        [
            "name": "get_news",
            "description": "Return cached headlines for a news topic tracked in the app.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "topic": [
                        "type": "string",
                        "enum": ["finance", "accounting", "economics", "ai", "all"],
                        "description": "Which topic's headlines to fetch, or \"all\" for every topic merged.",
                    ] as [String: Any],
                ] as [String: Any],
                "required": ["topic"],
            ] as [String: Any],
        ],
        [
            "name": "get_today_summary",
            "description": "Get today's overall momentum percentage and the status of every habit scheduled today.",
            "input_schema": ["type": "object", "properties": [String: Any]()] as [String: Any],
        ],
        [
            "name": "toggle_habit",
            "description": "Toggle a habit's completion for today — marks it done if not done, or not done if already done.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Habit name, or a distinctive substring of it."] as [String: Any],
                ] as [String: Any],
                "required": ["name"],
            ] as [String: Any],
        ],
        [
            "name": "log_skill_session",
            "description": "Log a practice session for a skill, incrementing its progress toward its target.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Skill name, or a distinctive substring of it."] as [String: Any],
                    "note": ["type": "string", "description": "Optional note about the session."] as [String: Any],
                ] as [String: Any],
                "required": ["name"],
            ] as [String: Any],
        ],
        [
            "name": "add_project_task",
            "description": "Add a new task to an existing project.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "project": ["type": "string", "description": "Project name, or a distinctive substring of it."] as [String: Any],
                    "title": ["type": "string", "description": "The task's title."] as [String: Any],
                ] as [String: Any],
                "required": ["project", "title"],
            ] as [String: Any],
        ],
        [
            "name": "get_github_repos",
            "description": "List the user's GitHub repositories (name, description, language, stars) so you can recall their coding projects.",
            "input_schema": ["type": "object", "properties": [String: Any]()] as [String: Any],
        ],
    ]
}
