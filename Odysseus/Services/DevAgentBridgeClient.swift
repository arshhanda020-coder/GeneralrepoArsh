//
//  DevAgentBridgeClient.swift
//  Odysseus
//
//  Talks to the companion service in bridge/server.js — a small Node process
//  you run on your Mac that wraps the real `claude` and `codex` CLIs. This
//  is what turns DevAgentBridgeView from a "not connected" placeholder into
//  an actual connection: real prompts, run against a real working directory,
//  through the real CLI, not a chat-completion stand-in like AgentRunner.
//

import Foundation

enum BridgeError: LocalizedError {
    case noURL
    case unauthorized
    case unreachable
    case server(String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .noURL: return "No bridge URL set."
        case .unauthorized: return "Bridge rejected the token — check it matches what the server printed on startup."
        case .unreachable: return "Couldn't reach the bridge. Is server.js running, and is the URL correct?"
        case .server(let message): return message
        case .malformedResponse: return "Bridge returned something unexpected."
        }
    }
}

struct BridgeAgentStatus {
    let available: Bool
    let version: String?
}

struct BridgeHealth {
    let claudeCode: BridgeAgentStatus
    let codex: BridgeAgentStatus
}

struct BridgeRunResult {
    let ok: Bool
    let output: String
    let sessionId: String?
    let costUSD: Double?
    let error: String?
}

enum BridgeTaskStatus: String {
    case working, completed, error
}

/// One entry in the bridge's task list — mirrors what `claude`'s own
/// background-task dashboard shows in a terminal, just polled over HTTP
/// instead of watched live in a TTY.
struct BridgeTask: Identifiable {
    let id: String
    let agent: String
    let prompt: String
    let status: BridgeTaskStatus
    let output: String
    let sessionId: String?
    let costUSD: Double?
    let error: String?
    let startedAt: Date
    let finishedAt: Date?
}

enum DevAgentBridgeClient {
    /// Cheap, unauthenticated reachability check — GET / just confirms
    /// *something* answering as odysseus-bridge is listening at this URL.
    static func ping(baseURL: String) async -> Bool {
        guard let url = normalizedURL(baseURL, path: "/") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return json["service"] as? String == "odysseus-bridge"
    }

    static func health(baseURL: String, token: String) async throws -> BridgeHealth {
        let json = try await get(baseURL: baseURL, path: "/health", token: token)
        guard let agents = json["agents"] as? [String: Any] else { throw BridgeError.malformedResponse }
        return BridgeHealth(
            claudeCode: agentStatus(agents["claudeCode"]),
            codex: agentStatus(agents["codex"])
        )
    }

    static func run(
        baseURL: String,
        token: String,
        agent: String,
        prompt: String,
        cwd: String,
        fullAuto: Bool
    ) async throws -> BridgeRunResult {
        guard let url = normalizedURL(baseURL, path: "/run") else { throw BridgeError.noURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600 // agent runs can genuinely take minutes
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "agent": agent, "prompt": prompt, "cwd": cwd, "fullAuto": fullAuto,
        ])

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.unreachable }
        guard http.statusCode != 401 else { throw BridgeError.unauthorized }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BridgeError.malformedResponse
        }
        if http.statusCode >= 400, let error = json["error"] as? String { throw BridgeError.server(error) }

        return BridgeRunResult(
            ok: json["ok"] as? Bool ?? false,
            output: json["output"] as? String ?? "",
            sessionId: json["sessionId"] as? String,
            costUSD: json["costUSD"] as? Double,
            error: json["error"] as? String
        )
    }

    /// Starts a run in the background and returns immediately — the bridge
    /// keeps working the task after this call returns. Poll `listTasks` (or
    /// `task(id:)`) to watch it move from `.working` to `.completed`/`.error`.
    static func startTask(
        baseURL: String,
        token: String,
        agent: String,
        prompt: String,
        cwd: String,
        fullAuto: Bool
    ) async throws -> BridgeTask {
        guard let url = normalizedURL(baseURL, path: "/tasks") else { throw BridgeError.noURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15 // this call itself just enqueues — it shouldn't block on the run
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "agent": agent, "prompt": prompt, "cwd": cwd, "fullAuto": fullAuto,
        ])

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.unreachable }
        guard http.statusCode != 401 else { throw BridgeError.unauthorized }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BridgeError.malformedResponse
        }
        if http.statusCode >= 400, let error = json["error"] as? String { throw BridgeError.server(error) }
        guard let task = decodeTask(json) else { throw BridgeError.malformedResponse }
        return task
    }

    /// Full task list for one agent, newest first — this is the dashboard feed.
    static func listTasks(baseURL: String, token: String, agent: String) async throws -> [BridgeTask] {
        let json = try await get(baseURL: baseURL, path: "/tasks?agent=\(agent)", token: token)
        guard let raw = json["tasks"] as? [[String: Any]] else { throw BridgeError.malformedResponse }
        return raw.compactMap(decodeTask)
    }

    // MARK: - Helpers

    private static func decodeTask(_ json: [String: Any]) -> BridgeTask? {
        guard let id = json["id"] as? String,
              let agent = json["agent"] as? String,
              let prompt = json["prompt"] as? String,
              let statusRaw = json["status"] as? String,
              let status = BridgeTaskStatus(rawValue: statusRaw),
              let startedAt = isoDate(json["startedAt"])
        else { return nil }
        return BridgeTask(
            id: id,
            agent: agent,
            prompt: prompt,
            status: status,
            output: json["output"] as? String ?? "",
            sessionId: json["sessionId"] as? String,
            costUSD: json["costUSD"] as? Double,
            error: json["error"] as? String,
            startedAt: startedAt,
            finishedAt: isoDate(json["finishedAt"])
        )
    }

    private static func isoDate(_ raw: Any?) -> Date? {
        guard let string = raw as? String else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }

    private static func get(baseURL: String, path: String, token: String) async throws -> [String: Any] {
        guard let url = normalizedURL(baseURL, path: path) else { throw BridgeError.noURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.unreachable }
        guard http.statusCode != 401 else { throw BridgeError.unauthorized }
        guard http.statusCode == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BridgeError.malformedResponse
        }
        return json
    }

    private static func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw BridgeError.unreachable
        }
    }

    private static func agentStatus(_ raw: Any?) -> BridgeAgentStatus {
        let dict = raw as? [String: Any]
        return BridgeAgentStatus(available: dict?["available"] as? Bool ?? false, version: dict?["version"] as? String)
    }

    /// Accepts URLs with or without a scheme/trailing slash — the app's text
    /// field placeholder ("http://192.168.x.x:PORT") is easy to mistype.
    private static func normalizedURL(_ raw: String, path: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "http://" + trimmed }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed + path)
    }
}
