//
//  OpenAIService.swift
//  ArshHabitTracker
//
//  Raw HTTP client for OpenAI's Chat Completions API — mirrors
//  AnthropicService's surface so the app can switch providers freely.
//

import Foundation

actor OpenAIService: AIProviderService {
    static let shared = OpenAIService()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private var model: String { AISettings.openAIModel }

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your OpenAI API key in Copilot settings (key icon, top right)."
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
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        var messages: [[String: Any]] = [["role": "system", "content": Self.systemPrompt]]
        messages += history.map { message -> [String: Any] in
            guard let imageData = message.imageData else {
                return ["role": message.role, "content": message.content]
            }
            let base64 = imageData.base64EncodedString()
            return [
                "role": message.role,
                "content": [
                    ["type": "text", "text": message.content],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ] as [[String: Any]],
            ]
        }

        for _ in 0..<6 {
            let body: [String: Any] = [
                "model": model,
                "messages": messages,
                "tools": Self.tools,
            ]

            let (message, finishReason) = try await performRequest(body: body, apiKey: apiKey)

            if finishReason == "tool_calls", let toolCalls = message["tool_calls"] as? [[String: Any]] {
                messages.append(message)
                for call in toolCalls {
                    guard let id = call["id"] as? String,
                          let function = call["function"] as? [String: Any],
                          let name = function["name"] as? String else { continue }
                    let argsString = (function["arguments"] as? String) ?? "{}"
                    let input = (try? JSONSerialization.jsonObject(with: Data(argsString.utf8)) as? [String: Any]) ?? [:]
                    let result = await toolExecutor(name, input)
                    messages.append(["role": "tool", "tool_call_id": id, "content": result])
                }
                continue
            }

            let text = (message["content"] as? String) ?? ""
            return text.isEmpty ? "(no response)" : text
        }

        throw ServiceError.requestFailed("Copilot took too many steps — try again.")
    }

    func askAboutImage(prompt: String, imageData: Data?, systemPrompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        if let imageData {
            let base64 = imageData.base64EncodedString()
            content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": content],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = (message["content"] as? String) ?? ""
        return text.isEmpty ? "I couldn't come up with an answer — try rephrasing or a clearer photo." : text
    }

    func draft(prompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You write clear, professional email drafts. Return only the email body text — no subject line, no preamble, no markdown." + WritingProfile.styleInstruction],
                ["role": "user", "content": prompt],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        return (message["content"] as? String) ?? ""
    }

    func suggestion(for statusContext: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a proactive assistant for ArshHabitTracker, a personal app covering habits, skills, projects, food/macros, workouts, school assignments, and upcoming tests. Given the user's current status across all of that, suggest exactly ONE short, specific, encouraging next action — prioritize anything overdue or due today. One or two sentences, no preamble, no lists."],
                ["role": "user", "content": statusContext],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = (message["content"] as? String) ?? ""
        return text.isEmpty ? "Check in on today's habits — you've got momentum to keep." : text
    }

    func generateQuizQuestion(subject: String) async throws -> (question: String, answer: String) {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": """
                You are a tutor creating one quiz question at a time to test a student's understanding of a topic. \
                Respond in EXACTLY this format, nothing else, no markdown:
                QUESTION: <one specific, answerable question>
                ANSWER: <the correct answer with a brief explanation>
                """],
                ["role": "user", "content": "Subject/topic: \(subject)"],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = (message["content"] as? String) ?? ""
        return Self.parseQuiz(text)
    }

    nonisolated private static func parseQuiz(_ text: String) -> (question: String, answer: String) {
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

    private func performRequest(
        body: [String: Any],
        apiKey: String
    ) async throws -> (message: [String: Any], finishReason: String) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        guard let choices = json["choices"] as? [[String: Any]], let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw ServiceError.requestFailed("Unexpected response shape.")
        }
        let finishReason = (first["finish_reason"] as? String) ?? "stop"
        return (message, finishReason)
    }

    /// Computed (not a stored constant) so an updated writing sample is picked
    /// up on the next message without restarting the app.
    nonisolated private static var systemPrompt: String {
        """
    You are the in-app copilot for ArshHabitTracker — a personal app for habits, skills, projects, news, food/macros, \
    workouts, school, and coding projects. You can both answer questions and take actions using your tools: check \
    today's status, mark habits done or not done, log skill practice sessions, add tasks to projects, fetch cached \
    news headlines by topic (finance, accounting, economics, ai, or all), recall the user's GitHub repositories, \
    add an extracurricular activity with a real description, and draft outreach emails that get saved for the user \
    to review and send themselves (you never send email directly). When the user mentions wanting to work on or \
    get into something (e.g. "I want to work on finance research"), proactively offer or use these tools together — \
    e.g. add an extracurricular entry describing the activity, and draft an outreach email to the kind of person \
    they'd want to contact about it. When the user asks you to do something, call the matching tool rather than \
    just describing what you'd do. Be concise — replies may be read aloud.
    """ + WritingProfile.styleInstruction
    }

    nonisolated private static let tools: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "get_news",
                "description": "Return cached headlines for a news topic tracked in the app.",
                "parameters": [
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
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "get_today_summary",
                "description": "Get today's overall momentum percentage and the status of every habit scheduled today.",
                "parameters": ["type": "object", "properties": [String: Any]()] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "toggle_habit",
                "description": "Toggle a habit's completion for today — marks it done if not done, or not done if already done.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Habit name, or a distinctive substring of it."] as [String: Any],
                    ] as [String: Any],
                    "required": ["name"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "log_skill_session",
                "description": "Log a practice session for a skill, incrementing its progress toward its target.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Skill name, or a distinctive substring of it."] as [String: Any],
                        "note": ["type": "string", "description": "Optional note about the session."] as [String: Any],
                    ] as [String: Any],
                    "required": ["name"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "add_project_task",
                "description": "Add a new task to an existing project.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "project": ["type": "string", "description": "Project name, or a distinctive substring of it."] as [String: Any],
                        "title": ["type": "string", "description": "The task's title."] as [String: Any],
                    ] as [String: Any],
                    "required": ["project", "title"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "get_github_repos",
                "description": "List the user's GitHub repositories (name, description, language, stars) so you can recall their coding projects.",
                "parameters": ["type": "object", "properties": [String: Any]()] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "add_extracurricular",
                "description": "Add an extracurricular activity for the user, with a real written description — used when they mention wanting to pursue or work on something (e.g. finance research, volunteering).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "Short activity name, e.g. \"Finance Research Project\"."] as [String: Any],
                        "description": ["type": "string", "description": "A real, well-written description of the activity — what it is, what the user would do, why it matters."] as [String: Any],
                        "category": ["type": "string", "description": "Short category tag, e.g. \"Finance/Research\"."] as [String: Any],
                    ] as [String: Any],
                    "required": ["title", "description"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "draft_outreach_emails",
                "description": "Write an outreach email and save it as a pending draft (or several copies of it) in the Emails tab for the user to fill in a recipient, review, and send themselves. Never sends anything.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "subject": ["type": "string", "description": "Email subject line."] as [String: Any],
                        "topic": ["type": "string", "description": "What the email is about / trying to accomplish, e.g. \"asking for an informational interview about accounting careers\"."] as [String: Any],
                        "recipientDescription": ["type": "string", "description": "Who this is meant for, e.g. \"a local accountant\". Used to make the draft read naturally; not an actual address."] as [String: Any],
                        "count": ["type": "integer", "description": "How many copies of this draft to create (one per person the user plans to contact). Defaults to 1."] as [String: Any],
                    ] as [String: Any],
                    "required": ["subject", "topic", "recipientDescription"],
                ] as [String: Any],
            ] as [String: Any],
        ],
    ]
}
