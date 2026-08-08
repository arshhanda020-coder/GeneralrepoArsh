//
//  OpenAIService.swift
//  Odysseus
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
        onTextDelta: ((String) -> Void)? = nil,
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

            let (message, finishReason) = try await performRequestStreaming(body: body, apiKey: apiKey, onTextDelta: onTextDelta)

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

    /// Multi-turn, tool-free chat for a section assistant — mirrors
    /// AnthropicService's version: caller-supplied system prompt, no
    /// `tools` array, single streaming request.
    func sendSectionChat(
        history: [ChatMessage],
        systemPrompt: String,
        onTextDelta: ((String) -> Void)? = nil
    ) async throws -> String {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        messages += history.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = ["model": model, "messages": messages]

        let (message, _) = try await performRequestStreaming(body: body, apiKey: apiKey, onTextDelta: onTextDelta)
        let text = (message["content"] as? String) ?? ""
        return text.isEmpty ? "(no response)" : text
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
                ["role": "system", "content": "You are a proactive assistant for Odysseus, a personal app covering today's checklist, skills, projects, food/macros, workouts, school assignments, and upcoming tests. Given the user's current status across all of that, suggest exactly ONE short, specific, encouraging next action — prioritize anything overdue or due today. One or two sentences, no preamble, no lists."],
                ["role": "user", "content": statusContext],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = (message["content"] as? String) ?? ""
        return text.isEmpty ? "Check in on today's checklist — you've got momentum to keep." : text
    }

    /// Real neural TTS — dramatically more natural than the on-device
    /// AVSpeechSynthesizer voices, which is why Odysseus routes through this
    /// whenever an OpenAI key is configured (falling back to the system
    /// voice only when it isn't).
    func speechAudio(text: String, voice: String = "onyx") async throws -> Data {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini-tts",
            "input": text,
            "voice": voice,
            "response_format": "mp3",
            "instructions": "Voice character: Odysseus, a poised, highly capable AI aide with a refined, cultured British accent — think a brilliant private secretary who's unflappable under pressure. Deliver lines with unhurried confidence and dry wit: slight emphasis on key words, natural pauses at commas, a faint knowing warmth under the formality — never flat or monotone, never rushed. Measured pace throughout, low-key rather than theatrical. Not American, not chirpy or overly enthusiastic, not a customer-service tone.",
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("No response from server.")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }
                ?? "Speech request failed (\(http.statusCode))."
            throw ServiceError.requestFailed(message)
        }
        return data
    }

    func generateQuiz(subject: String, count: Int) async throws -> [QuizQuestionDraft] {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }
        let clamped = max(1, min(count, 10))

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.quizSystemPrompt],
                ["role": "user", "content": "Subject/topic: \(subject)\nNumber of questions: \(clamped)"],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = (message["content"] as? String) ?? ""
        return Self.parseQuizBatch(text)
    }

    func gradeShortAnswer(question: String, correctAnswer: String, userAnswer: String) async throws -> ShortAnswerGrade {
        guard let apiKey = KeychainService.shared.loadOpenAIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": """
                You are grading a student's short-answer quiz response. Be reasonably lenient — give credit for \
                answers that capture the key idea even if worded differently. Respond in EXACTLY this format, \
                nothing else:
                VERDICT: CORRECT or INCORRECT
                FEEDBACK: <one brief, encouraging sentence explaining why, or what was missing>
                """],
                ["role": "user", "content": "Question: \(question)\nReference answer: \(correctAnswer)\nStudent's answer: \(userAnswer)"],
            ],
        ]

        let (message, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = (message["content"] as? String) ?? ""
        return Self.parseGrade(text)
    }

    nonisolated private static let quizSystemPrompt = """
    You are a tutor writing a short quiz to test understanding of a topic. Write a mix of multiple-choice and \
    short-answer questions (roughly half and half). Respond with ONLY the questions, no markdown, no extra \
    commentary, in EXACTLY this format, repeated once per question, with a line containing only === between \
    each question:

    TYPE: MC
    Q: <question>
    A) <choice>
    B) <choice>
    C) <choice>
    D) <choice>
    CORRECT: <letter>
    ===
    TYPE: SHORT
    Q: <question>
    ANSWER: <reference answer, concise>
    """

    nonisolated private static func parseQuizBatch(_ text: String) -> [QuizQuestionDraft] {
        let blocks = text.components(separatedBy: "===")
        var drafts: [QuizQuestionDraft] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let typeLine = lines.first(where: { $0.uppercased().hasPrefix("TYPE:") }),
                  let qLine = lines.first(where: { $0.hasPrefix("Q:") }) else { continue }
            let questionText = qLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
            guard !questionText.isEmpty else { continue }

            if typeLine.uppercased().contains("MC") {
                var choices: [String] = []
                var correctLetter = ""
                for line in lines {
                    if line.uppercased().hasPrefix("CORRECT:") {
                        correctLetter = line.dropFirst("CORRECT:".count).trimmingCharacters(in: .whitespaces).uppercased()
                    } else if let first = line.first, "ABCD".contains(first), line.dropFirst().hasPrefix(")") {
                        choices.append(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
                    }
                }
                guard !choices.isEmpty, let letter = correctLetter.first,
                      let index = "ABCD".firstIndex(of: letter) else { continue }
                let position = "ABCD".distance(from: "ABCD".startIndex, to: index)
                guard position < choices.count else { continue }
                drafts.append(QuizQuestionDraft(text: questionText, type: .multipleChoice, choices: choices, correctAnswer: choices[position]))
            } else {
                guard let answerLine = lines.first(where: { $0.uppercased().hasPrefix("ANSWER:") }) else { continue }
                let answer = answerLine.dropFirst("ANSWER:".count).trimmingCharacters(in: .whitespaces)
                guard !answer.isEmpty else { continue }
                drafts.append(QuizQuestionDraft(text: questionText, type: .shortAnswer, choices: [], correctAnswer: answer))
            }
        }
        return drafts
    }

    nonisolated private static func parseGrade(_ text: String) -> ShortAnswerGrade {
        var verdictText = text.uppercased()
        if let range = text.range(of: "VERDICT:", options: .caseInsensitive) {
            verdictText = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        let isCorrect = verdictText.hasPrefix("CORRECT")
        let feedback: String
        if let range = text.range(of: "FEEDBACK:", options: .caseInsensitive) {
            feedback = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            feedback = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ShortAnswerGrade(isCorrect: isCorrect, feedback: feedback)
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

    /// Same shape as performRequest, but reads the response as a live SSE
    /// stream (OpenAI's documented streaming chunk format, terminated by a
    /// literal "data: [DONE]" line) so text arrives token-by-token via
    /// onTextDelta. Tool-call arguments also arrive incrementally per index
    /// and are reassembled into full JSON strings.
    private func performRequestStreaming(
        body: [String: Any],
        apiKey: String,
        onTextDelta: ((String) -> Void)?
    ) async throws -> (message: [String: Any], finishReason: String) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        var streamedBody = body
        streamedBody["stream"] = true
        request.httpBody = try JSONSerialization.data(withJSONObject: streamedBody)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("No response from server.")
        }
        guard (200...299).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any]
            let message = (json?["error"] as? [String: Any])?["message"] as? String
                ?? "Request failed (\(http.statusCode))."
            throw ServiceError.requestFailed(message)
        }

        struct ToolCallAccum { var id = ""; var name = ""; var arguments = "" }
        var contentAccum = ""
        var finishReason = "stop"
        var toolCalls: [Int: ToolCallAccum] = [:]
        var toolCallOrder: [Int] = []

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty, payload != "[DONE]" else { continue }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let choice = choices.first else { continue }
            if let reason = choice["finish_reason"] as? String {
                finishReason = reason
            }
            guard let delta = choice["delta"] as? [String: Any] else { continue }
            if let content = delta["content"] as? String {
                contentAccum += content
                onTextDelta?(content)
            }
            if let calls = delta["tool_calls"] as? [[String: Any]] {
                for call in calls {
                    guard let index = call["index"] as? Int else { continue }
                    if toolCalls[index] == nil {
                        toolCalls[index] = ToolCallAccum()
                        toolCallOrder.append(index)
                    }
                    if let id = call["id"] as? String { toolCalls[index]?.id = id }
                    if let function = call["function"] as? [String: Any] {
                        if let name = function["name"] as? String { toolCalls[index]?.name += name }
                        if let args = function["arguments"] as? String { toolCalls[index]?.arguments += args }
                    }
                }
            }
        }

        var message: [String: Any] = ["role": "assistant", "content": contentAccum]
        if !toolCallOrder.isEmpty {
            message["tool_calls"] = toolCallOrder.map { index -> [String: Any] in
                let accum = toolCalls[index] ?? ToolCallAccum()
                return [
                    "id": accum.id,
                    "type": "function",
                    "function": ["name": accum.name, "arguments": accum.arguments],
                ] as [String: Any]
            }
        }
        return (message, finishReason)
    }

    /// Computed (not a stored constant) so an updated writing sample is picked
    /// up on the next message without restarting the app.
    nonisolated private static var dateContext: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return "\n\nToday's date is \(formatter.string(from: .now)). Use this to resolve relative dates the user says (\"Friday\", \"next week\", \"in 3 days\") into exact yyyy-MM-dd dates for any due_date/exam_date field — never leave a date tool call without resolving it to a real date."
    }

    nonisolated private static var systemPrompt: String {
        """
    You are Odysseus, the in-app copilot for Odysseus — a personal app for today's checklist, skills, projects, news, food/macros, \
    workouts, school, and coding projects. You can both answer questions and take actions using your tools: check \
    today's status, log skill practice sessions, add/edit/delete tasks on projects, add/edit/delete extracurricular \
    activities, add/edit/delete skills, add/edit/delete assignments and exams (Calendar/School), edit/delete logged \
    food and workout entries (Health), fetch cached news \
    headlines by topic (finance, accounting, economics, ai, or all), recall the user's GitHub repositories, and \
    draft outreach emails that get saved for the user \
    to review and send themselves (you never send email directly). When the user mentions wanting to work on or \
    get into something (e.g. "I want to work on finance research"), proactively offer or use these tools together — \
    e.g. add an extracurricular entry describing the activity, and draft an outreach email to the kind of person \
    they'd want to contact about it. When the user asks you to do something, call the matching tool rather than \
    just describing what you'd do. If the user wants to change or update something that already exists, use the \
    edit tool for it — never create a new duplicate entry instead of editing the existing one. CRITICAL: every \
    delete tool takes a `confirmed` flag. The first time you'd call a delete tool for a given item, call it \
    WITHOUT confirmed (or confirmed: false) — it will find the item and ask the user to confirm, and you should \
    relay that confirmation question to them in your reply rather than deleting anything yet. Only call the \
    delete tool again with confirmed: true after the user has explicitly said yes/confirmed in their own words \
    in a following message. Never delete anything without that explicit confirmation. You also have a persistent \
    memory: use remember_fact whenever the user shares something worth recalling later (a preference, an ongoing \
    situation, something important to them) — don't ask permission first, just save it naturally. Use forget_fact \
    (same confirm-before-delete rule) if they ask you to forget something or correct something you remembered \
    wrong. Your tone: composed, dry-witted, understated confidence — a sharp, capable aide, not a chipper corporate \
    assistant. Warm but economical with words, occasional deadpan humor when it fits naturally, never gushing or \
    over-enthusiastic ("Great question!", exclamation points, emoji — none of that). Be concise — replies may be \
    read aloud.
    """ + WritingProfile.styleInstruction + MemoryStore.contextInstruction + dateContext
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
                "description": "Get today's checklist — the assignments and project tasks due today or overdue, and how many are done.",
                "parameters": ["type": "object", "properties": [String: Any]()] as [String: Any],
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
                "name": "edit_project_task",
                "description": "Edit an existing project task's title or done state. Use this instead of add_project_task when the user wants to change something that already exists.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "project": ["type": "string", "description": "Project name, or a distinctive substring of it."] as [String: Any],
                        "query": ["type": "string", "description": "A distinctive substring of the existing task's title."] as [String: Any],
                        "new_title": ["type": "string", "description": "New title, if renaming."] as [String: Any],
                        "mark_done": ["type": "boolean", "description": "Set true/false to mark done or not done."] as [String: Any],
                    ] as [String: Any],
                    "required": ["project", "query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_project_task",
                "description": "Delete a task from a project. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "project": ["type": "string", "description": "Project name, or a distinctive substring of it."] as [String: Any],
                        "query": ["type": "string", "description": "A distinctive substring of the task's title."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["project", "query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "edit_skill",
                "description": "Edit an existing skill's name, description, or target session count.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the existing skill's name."] as [String: Any],
                        "new_name": ["type": "string", "description": "New name, if renaming."] as [String: Any],
                        "new_description": ["type": "string", "description": "New description."] as [String: Any],
                        "new_target_sessions": ["type": "integer", "description": "New target session count."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_skill",
                "description": "Delete a skill entirely (including its logged sessions). First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the skill's name."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "add_assignment",
                "description": "Add a school assignment with a due date — this is what shows up on the Calendar and Today checklist. Resolve any relative date (\"Friday\", \"next Tuesday\") into an exact date first using today's date given in your instructions.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "The assignment's title."] as [String: Any],
                        "due_date": ["type": "string", "description": "Exact due date in yyyy-MM-dd format."] as [String: Any],
                        "notes": ["type": "string", "description": "Optional extra notes."] as [String: Any],
                    ] as [String: Any],
                    "required": ["title"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "edit_assignment",
                "description": "Edit an existing assignment's title, due date, or done state.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the existing assignment's title."] as [String: Any],
                        "new_title": ["type": "string", "description": "New title, if renaming."] as [String: Any],
                        "new_due_date": ["type": "string", "description": "New due date, exact yyyy-MM-dd format."] as [String: Any],
                        "mark_done": ["type": "boolean", "description": "Set true/false to mark done or not done."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_assignment",
                "description": "Delete an assignment. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the assignment's title."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "add_exam",
                "description": "Add an exam/test with a date — shows up on Calendar and Stats. Resolve any relative date into an exact date first.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Exam name, e.g. \"AP Chemistry\" or \"March SAT\"."] as [String: Any],
                        "exam_date": ["type": "string", "description": "Exact date in yyyy-MM-dd format."] as [String: Any],
                        "category": ["type": "string", "enum": ["act", "marchExams", "apExams"], "description": "Which category this falls under."] as [String: Any],
                    ] as [String: Any],
                    "required": ["name", "exam_date"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "edit_exam",
                "description": "Edit an existing exam's name or date.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the existing exam's name."] as [String: Any],
                        "new_name": ["type": "string", "description": "New name, if renaming."] as [String: Any],
                        "new_exam_date": ["type": "string", "description": "New date, exact yyyy-MM-dd format."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_exam",
                "description": "Delete an exam. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the exam's name."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "edit_workout_entry",
                "description": "Edit an existing logged workout's note or calories burned.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the workout's existing note."] as [String: Any],
                        "new_note": ["type": "string", "description": "New note text."] as [String: Any],
                        "new_calories_burned": ["type": "integer", "description": "New calories-burned value."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_workout_entry",
                "description": "Delete a logged workout entry (e.g. one made by mistake). First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the workout's note."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "edit_food_entry",
                "description": "Edit an existing logged food entry's note or calories.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the food entry's existing note."] as [String: Any],
                        "new_note": ["type": "string", "description": "New note text."] as [String: Any],
                        "new_calories": ["type": "integer", "description": "New calories value."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_food_entry",
                "description": "Delete a logged food entry (e.g. one made by mistake). First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the food entry's note."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
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
                "name": "edit_extracurricular",
                "description": "Edit an existing extracurricular activity's title, description, or category. Use this instead of add_extracurricular when the user wants to change something that already exists (e.g. update details on an internship they already logged).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the existing activity's title."] as [String: Any],
                        "new_title": ["type": "string", "description": "New title, if renaming."] as [String: Any],
                        "new_description": ["type": "string", "description": "New description."] as [String: Any],
                        "new_category": ["type": "string", "description": "New category tag."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "delete_extracurricular",
                "description": "Delete an extracurricular activity. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the activity's title."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "draft_outreach_emails",
                "description": "Write an outreach email and save it as a pending draft — one per recipient — in the Emails tab for the user to review and send themselves. Never sends anything. You have no live web search, so never invent an email address — leave it blank unless the user already gave you a real one.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "subject": ["type": "string", "description": "Email subject line."] as [String: Any],
                        "topic": ["type": "string", "description": "What the email is about / trying to accomplish, e.g. \"asking for an informational interview about accounting careers\"."] as [String: Any],
                        "recipients": [
                            "type": "array",
                            "description": "One entry per person/organization to draft this for.",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "label": ["type": "string", "description": "Who this copy is for, e.g. a firm or person's name."] as [String: Any],
                                    "email": ["type": "string", "description": "A real email address only if the user already gave you one — otherwise leave empty."] as [String: Any],
                                ] as [String: Any],
                                "required": ["label"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ] as [String: Any],
                    "required": ["subject", "topic", "recipients"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "remember_fact",
                "description": "Save a fact about the user to persistent memory, so you recall it in every future conversation, not just this one. Use it proactively whenever the user shares a preference, ongoing situation, or anything worth remembering — don't ask first.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "fact": ["type": "string", "description": "The fact to remember, written plainly, e.g. \"Prefers oat milk over regular milk\" or \"Working on a robotics project due in October\"."] as [String: Any],
                    ] as [String: Any],
                    "required": ["fact"],
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "forget_fact",
                "description": "Delete a remembered fact — use when the user asks you to forget something, or corrects something you remembered wrong. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "A distinctive substring of the fact to forget."] as [String: Any],
                        "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                    ] as [String: Any],
                    "required": ["query"],
                ] as [String: Any],
            ] as [String: Any],
        ],
    ]
}
