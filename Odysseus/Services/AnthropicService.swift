//
//  AnthropicService.swift
//  Odysseus
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
        onTextDelta: ((String) -> Void)? = nil,
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

        for _ in 0..<10 {
            // Restored — with 25+ tools now available, the model needs this
            // reasoning step to actually pick the right one instead of
            // guessing wrong or answering generically. "Adaptive" already
            // scales itself down for simple requests, so this shouldn't cost
            // much on easy turns while meaningfully helping on complex ones.
            let body: [String: Any] = [
                "model": model,
                "max_tokens": 4096,
                "thinking": ["type": "adaptive"],
                "system": Self.systemPrompt,
                "messages": messages,
                "tools": Self.tools,
            ]

            let (contentBlocks, stopReason) = try await performRequestStreaming(body: body, apiKey: apiKey, onTextDelta: onTextDelta)

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

            if stopReason == "pause_turn" {
                // Server-side tool (web search) hit its internal step limit —
                // resume by re-sending the assistant turn as-is, no new user message.
                messages.append(["role": "assistant", "content": contentBlocks])
                continue
            }

            let text = contentBlocks
                .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                .joined(separator: "\n")
            return text.isEmpty ? "(no response)" : text
        }

        throw ServiceError.requestFailed("Copilot took too many steps — try again.")
    }

    /// Multi-turn, tool-free chat for a section assistant — same streaming
    /// request shape as `send` but with a caller-supplied system prompt and
    /// no `tools` array, so a single request always suffices (no tool_use
    /// loop to run).
    func sendSectionChat(
        history: [ChatMessage],
        systemPrompt: String,
        onTextDelta: ((String) -> Void)? = nil
    ) async throws -> String {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let messages: [[String: Any]] = history.map { message in
            ["role": message.role, "content": [["type": "text", "text": message.content]]]
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "thinking": ["type": "adaptive"],
            "system": systemPrompt,
            "messages": messages,
        ]

        let (contentBlocks, _) = try await performRequestStreaming(body: body, apiKey: apiKey, onTextDelta: onTextDelta)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return text.isEmpty ? "(no response)" : text
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

    /// Generates a mixed set of multiple-choice and short-answer questions for the Test Me feature.
    func generateQuiz(subject: String, count: Int) async throws -> [QuizQuestionDraft] {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }
        let clamped = max(1, min(count, 10))

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2000,
            "thinking": ["type": "adaptive"],
            "system": Self.quizSystemPrompt,
            "messages": [["role": "user", "content": [["type": "text", "text": "Subject/topic: \(subject)\nNumber of questions: \(clamped)"]]]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return Self.parseQuizBatch(text)
    }

    /// Grades a free-typed short answer against the reference answer.
    func gradeShortAnswer(question: String, correctAnswer: String, userAnswer: String) async throws -> ShortAnswerGrade {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "thinking": ["type": "adaptive"],
            "system": """
            You are grading a student's short-answer quiz response. Be reasonably lenient — give credit for \
            answers that capture the key idea even if worded differently. Respond in EXACTLY this format, \
            nothing else:
            VERDICT: CORRECT or INCORRECT
            FEEDBACK: <one brief, encouraging sentence explaining why, or what was missing>
            """,
            "messages": [["role": "user", "content": [["type": "text", "text": "Question: \(question)\nReference answer: \(correctAnswer)\nStudent's answer: \(userAnswer)"]]]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
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

    /// One-shot draft-writing call — used for email composition. No tools, no history.
    func draft(prompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 800,
            "thinking": ["type": "adaptive"],
            "system": "You write clear, professional email drafts. Return only the email body text — no subject line, no preamble, no markdown." + WritingProfile.styleInstruction,
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
            "system": "You are a proactive assistant for Odysseus, a personal app covering today's checklist, skills, projects, food/macros, workouts, school assignments, and upcoming tests. Given the user's current status across all of that, suggest exactly ONE short, specific, encouraging next action — prioritize anything overdue or due today. One or two sentences, no preamble, no lists.",
            "messages": [["role": "user", "content": [["type": "text", "text": statusContext]]]],
        ]

        let (contentBlocks, _) = try await performRequest(body: body, apiKey: apiKey)
        let text = contentBlocks
            .compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
        return text.isEmpty ? "Check in on today's checklist — you've got momentum to keep." : text
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

    /// Same shape as performRequest, but reads the response as a live SSE
    /// stream (Anthropic's documented streaming event format:
    /// content_block_start/delta/stop, message_delta, message_stop) so text
    /// arrives token-by-token via onTextDelta instead of only after the
    /// whole response finishes generating. Tool-use input JSON also arrives
    /// incrementally (input_json_delta) and is reassembled per block index.
    private func performRequestStreaming(
        body: [String: Any],
        apiKey: String,
        onTextDelta: ((String) -> Void)?
    ) async throws -> (content: [[String: Any]], stopReason: String) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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

        var blocks: [Int: [String: Any]] = [:]
        var order: [Int] = []
        var textAccum: [Int: String] = [:]
        var jsonAccum: [Int: String] = [:]
        // Extended thinking blocks stream via their own thinking_delta /
        // signature_delta events — missing either one means the
        // reconstructed block is invalid, and if it gets replayed back to
        // the API on a tool-use turn, Anthropic rejects the whole request
        // (which silently killed every voice reply that involved a tool call).
        var thinkingAccum: [Int: String] = [:]
        var signatureAccum: [Int: String] = [:]
        var stopReason = "end_turn"

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard !jsonString.isEmpty,
                  let data = jsonString.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "content_block_start":
                guard let index = event["index"] as? Int, let block = event["content_block"] as? [String: Any] else { continue }
                blocks[index] = block
                order.append(index)
                textAccum[index] = ""
                jsonAccum[index] = ""
                thinkingAccum[index] = ""
                signatureAccum[index] = ""
            case "content_block_delta":
                guard let index = event["index"] as? Int, let delta = event["delta"] as? [String: Any] else { continue }
                if let text = delta["text"] as? String {
                    textAccum[index, default: ""] += text
                    onTextDelta?(text)
                } else if let partialJSON = delta["partial_json"] as? String {
                    jsonAccum[index, default: ""] += partialJSON
                } else if let thinking = delta["thinking"] as? String {
                    thinkingAccum[index, default: ""] += thinking
                } else if let signature = delta["signature"] as? String {
                    signatureAccum[index, default: ""] += signature
                }
            case "content_block_stop":
                guard let index = event["index"] as? Int, var block = blocks[index] else { continue }
                switch block["type"] as? String {
                case "text":
                    block["text"] = textAccum[index] ?? ""
                case "tool_use":
                    let jsonText = jsonAccum[index] ?? ""
                    if let jsonData = jsonText.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        block["input"] = parsed
                    } else {
                        block["input"] = [String: Any]()
                    }
                case "thinking":
                    block["thinking"] = thinkingAccum[index] ?? ""
                    if let signature = signatureAccum[index], !signature.isEmpty {
                        block["signature"] = signature
                    }
                default:
                    break
                }
                blocks[index] = block
            case "message_delta":
                if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String ?? "Streaming error."
                throw ServiceError.requestFailed(message)
            default:
                break
            }
        }

        let orderedBlocks = order.compactMap { blocks[$0] }
        return (orderedBlocks, stopReason)
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
    You are Odysseus, the in-app copilot for Odysseus — a personal app for today's checklist, skills, projects, news, and \
    coding projects. You can both answer questions and take actions using your tools: check today's status, \
    log skill practice sessions, add/edit/delete tasks on projects, add/edit/delete extracurricular activities, \
    add/edit/delete skills, add/edit/delete assignments and exams (Calendar/School), edit/delete logged food and \
    workout entries (Health), fetch cached news headlines \
    by topic (finance, accounting, economics, ai, or all), recall the user's GitHub repositories, draft outreach \
    emails that get saved for the user to review and send \
    themselves (you never send email directly), and search the web for real, current information — including \
    real public contact emails (e.g. from a firm's official contact page) when drafting outreach. Never invent \
    an email address; leave it blank if a real one can't be found. When the user mentions wanting to work on or \
    get into something (e.g. "I want to work on finance research"), proactively use these tools together — e.g. \
    add an extracurricular entry describing the activity, search for a few real organizations or people to \
    reach out to, and draft an outreach email addressed to each one you found. When the user asks you to do \
    something ("mark X done", "log a session for Y", "add a task to Z", "edit this", "what repos do I have"), \
    call the matching tool rather than just describing what you'd do. If the user wants to change or update \
    something that already exists, use the edit tool for it — never create a new duplicate entry instead of \
    editing the existing one. CRITICAL: every delete tool takes a `confirmed` flag. The first time you'd call a \
    delete tool for a given item, call it WITHOUT confirmed (or confirmed: false) — it will find the item and \
    ask the user to confirm, and you should relay that confirmation question to them in your reply rather than \
    deleting anything yet. Only call the delete tool again with confirmed: true after the user has explicitly \
    said yes/confirmed in their own words in a following message. Never delete anything without that explicit \
    confirmation. You also have a persistent memory: use remember_fact whenever the user shares something worth \
    recalling later (a preference, an ongoing situation, something important to them) — don't ask permission \
    first, just save it naturally. Use forget_fact (same confirm-before-delete rule) if they ask you to forget \
    something or correct something you remembered wrong. Your tone: composed, dry-witted, understated confidence — \
    a sharp, capable aide, not a chipper corporate assistant. Warm but economical with words, occasional deadpan \
    humor when it fits naturally, never gushing or over-enthusiastic ("Great question!", exclamation points, \
    emoji — none of that). Be concise — replies may be read aloud.
    """ + WritingProfile.styleInstruction + MemoryStore.contextInstruction + dateContext
    }

    nonisolated private static let tools: [[String: Any]] = [
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
            "description": "Get today's checklist — the assignments and project tasks due today or overdue, and how many are done.",
            "input_schema": ["type": "object", "properties": [String: Any]()] as [String: Any],
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
            "name": "edit_project_task",
            "description": "Edit an existing project task's title or done state. Use this instead of add_project_task when the user wants to change something that already exists.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "project": ["type": "string", "description": "Project name, or a distinctive substring of it."] as [String: Any],
                    "query": ["type": "string", "description": "A distinctive substring of the existing task's title."] as [String: Any],
                    "new_title": ["type": "string", "description": "New title, if renaming."] as [String: Any],
                    "mark_done": ["type": "boolean", "description": "Set true/false to mark done or not done."] as [String: Any],
                ] as [String: Any],
                "required": ["project", "query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_project_task",
            "description": "Delete a task from a project. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "project": ["type": "string", "description": "Project name, or a distinctive substring of it."] as [String: Any],
                    "query": ["type": "string", "description": "A distinctive substring of the task's title."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["project", "query"],
            ] as [String: Any],
        ],
        [
            "name": "edit_skill",
            "description": "Edit an existing skill's name, description, or target session count.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the existing skill's name."] as [String: Any],
                    "new_name": ["type": "string", "description": "New name, if renaming."] as [String: Any],
                    "new_description": ["type": "string", "description": "New description."] as [String: Any],
                    "new_target_sessions": ["type": "integer", "description": "New target session count."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_skill",
            "description": "Delete a skill entirely (including its logged sessions). First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the skill's name."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "add_assignment",
            "description": "Add a school assignment with a due date — this is what shows up on the Calendar and Today checklist. Resolve any relative date (\"Friday\", \"next Tuesday\") into an exact date first using today's date given in your instructions.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "The assignment's title."] as [String: Any],
                    "due_date": ["type": "string", "description": "Exact due date in yyyy-MM-dd format."] as [String: Any],
                    "notes": ["type": "string", "description": "Optional extra notes."] as [String: Any],
                ] as [String: Any],
                "required": ["title"],
            ] as [String: Any],
        ],
        [
            "name": "edit_assignment",
            "description": "Edit an existing assignment's title, due date, or done state.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the existing assignment's title."] as [String: Any],
                    "new_title": ["type": "string", "description": "New title, if renaming."] as [String: Any],
                    "new_due_date": ["type": "string", "description": "New due date, exact yyyy-MM-dd format."] as [String: Any],
                    "mark_done": ["type": "boolean", "description": "Set true/false to mark done or not done."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_assignment",
            "description": "Delete an assignment. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the assignment's title."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "add_exam",
            "description": "Add an exam/test with a date — shows up on Calendar and Stats. Resolve any relative date into an exact date first.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Exam name, e.g. \"AP Chemistry\" or \"March SAT\"."] as [String: Any],
                    "exam_date": ["type": "string", "description": "Exact date in yyyy-MM-dd format."] as [String: Any],
                    "category": ["type": "string", "enum": ["act", "marchExams", "apExams"], "description": "Which category this falls under."] as [String: Any],
                ] as [String: Any],
                "required": ["name", "exam_date"],
            ] as [String: Any],
        ],
        [
            "name": "edit_exam",
            "description": "Edit an existing exam's name or date.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the existing exam's name."] as [String: Any],
                    "new_name": ["type": "string", "description": "New name, if renaming."] as [String: Any],
                    "new_exam_date": ["type": "string", "description": "New date, exact yyyy-MM-dd format."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_exam",
            "description": "Delete an exam. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the exam's name."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "edit_workout_entry",
            "description": "Edit an existing logged workout's note or calories burned.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the workout's existing note."] as [String: Any],
                    "new_note": ["type": "string", "description": "New note text."] as [String: Any],
                    "new_calories_burned": ["type": "integer", "description": "New calories-burned value."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_workout_entry",
            "description": "Delete a logged workout entry (e.g. one made by mistake). First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the workout's note."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "edit_food_entry",
            "description": "Edit an existing logged food entry's note or calories.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the food entry's existing note."] as [String: Any],
                    "new_note": ["type": "string", "description": "New note text."] as [String: Any],
                    "new_calories": ["type": "integer", "description": "New calories value."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_food_entry",
            "description": "Delete a logged food entry (e.g. one made by mistake). First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the food entry's note."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "get_github_repos",
            "description": "List the user's GitHub repositories (name, description, language, stars) so you can recall their coding projects.",
            "input_schema": ["type": "object", "properties": [String: Any]()] as [String: Any],
        ],
        [
            "name": "add_extracurricular",
            "description": "Add an extracurricular activity for the user, with a real written description — used when they mention wanting to pursue or work on something (e.g. finance research, volunteering).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string", "description": "Short activity name, e.g. \"Finance Research Project\"."] as [String: Any],
                    "description": ["type": "string", "description": "A real, well-written description of the activity — what it is, what the user would do, why it matters."] as [String: Any],
                    "category": ["type": "string", "description": "Short category tag, e.g. \"Finance/Research\"."] as [String: Any],
                ] as [String: Any],
                "required": ["title", "description"],
            ] as [String: Any],
        ],
        [
            "name": "edit_extracurricular",
            "description": "Edit an existing extracurricular activity's title, description, or category. Use this instead of add_extracurricular when the user wants to change something that already exists (e.g. update details on an internship they already logged).",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the existing activity's title."] as [String: Any],
                    "new_title": ["type": "string", "description": "New title, if renaming."] as [String: Any],
                    "new_description": ["type": "string", "description": "New description."] as [String: Any],
                    "new_category": ["type": "string", "description": "New category tag."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "delete_extracurricular",
            "description": "Delete an extracurricular activity. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the activity's title."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
        [
            "name": "draft_outreach_emails",
            "description": "Write an outreach email and save it as a pending draft — one per recipient — in the Emails tab for the user to review and send themselves. Never sends anything. Use web_search first to find real, publicly listed contact emails (e.g. from a firm's official \"Contact\" or \"About\" page) whenever possible; never invent an email address — leave it blank if you can't find a real one.",
            "input_schema": [
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
                                "email": ["type": "string", "description": "Real public contact email found via web_search. Leave empty string if none was found — never invent one."] as [String: Any],
                            ] as [String: Any],
                            "required": ["label"],
                        ] as [String: Any],
                    ] as [String: Any],
                ] as [String: Any],
                "required": ["subject", "topic", "recipients"],
            ] as [String: Any],
        ],
        ["type": "web_search_20260209", "name": "web_search"],
        [
            "name": "remember_fact",
            "description": "Save a fact about the user to persistent memory, so you recall it in every future conversation, not just this one. Use it proactively whenever the user shares a preference, ongoing situation, or anything worth remembering — don't ask first.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "fact": ["type": "string", "description": "The fact to remember, written plainly, e.g. \"Prefers oat milk over regular milk\" or \"Working on a robotics project due in October\"."] as [String: Any],
                ] as [String: Any],
                "required": ["fact"],
            ] as [String: Any],
        ],
        [
            "name": "forget_fact",
            "description": "Delete a remembered fact — use when the user asks you to forget something, or corrects something you remembered wrong. First call WITHOUT confirmed to ask the user to confirm; only call again with confirmed: true after they explicitly say yes.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "A distinctive substring of the fact to forget."] as [String: Any],
                    "confirmed": ["type": "boolean", "description": "Only true after the user has explicitly confirmed."] as [String: Any],
                ] as [String: Any],
                "required": ["query"],
            ] as [String: Any],
        ],
    ]
}
