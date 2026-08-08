//
//  ElevenLabsService.swift
//  Odysseus
//
//  Real neural TTS from ElevenLabs — a different tier of voice quality/
//  character than OpenAI's preset voices, which is why this is the primary
//  voice path when a key + voice ID are configured (OpenAI TTS becomes the
//  fallback, then the on-device system voice after that).
//

import Foundation

/// Free-text voice ID on purpose — ElevenLabs' voice library is huge and
/// changes over time, and picking/previewing a voice happens on their site
/// or app, not something this app can browse. The user pastes the ID of
/// whichever voice they picked there.
nonisolated enum ElevenLabsSettings {
    private static let voiceIDKey = "elevenlabs_voice_id"

    /// The "Odysseus" voice, picked and named by the user — the default so
    /// it's already in place without re-entering it in Settings. Still
    /// overridable there if they ever want to switch voices.
    private static let defaultVoiceID = "av1BMOR1GPgThz9p4fLo"

    static var voiceID: String? {
        get { UserDefaults.standard.string(forKey: voiceIDKey) ?? defaultVoiceID }
        set { UserDefaults.standard.set(newValue, forKey: voiceIDKey) }
    }
}

actor ElevenLabsService {
    static let shared = ElevenLabsService()

    enum ServiceError: LocalizedError {
        case notConfigured
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Add your ElevenLabs API key and a voice ID in AI Settings."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private init() {}

    func speechAudio(text: String) async throws -> Data {
        guard let apiKey = KeychainService.shared.loadElevenLabsKey(), !apiKey.isEmpty,
              let voiceID = ElevenLabsSettings.voiceID, !voiceID.isEmpty else {
            throw ServiceError.notConfigured
        }

        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?output_format=mp3_44100_128")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            // turbo v2.5 is close to eleven_multilingual_v2 quality at much
            // lower latency — the right tradeoff for a conversational voice.
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.15,
                "use_speaker_boost": true,
            ] as [String: Any],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("No response from server.")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["detail"] as? [String: Any])?["message"] as? String }
                ?? "ElevenLabs request failed (\(http.statusCode))."
            throw ServiceError.requestFailed(message)
        }
        return data
    }
}
