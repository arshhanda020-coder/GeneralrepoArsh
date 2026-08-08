//
//  VoiceManager.swift
//  Odysseus
//

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var isSpeaking = false
    @Published var statusMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speechCompletion: (() -> Void)?
    private var speechToken = 0
    /// Chunked TTS pipeline — each chunk (a few sentences, not one) is
    /// requested concurrently, and playback starts as soon as chunk 0 is
    /// ready instead of waiting for the whole reply to synthesize. Grouping
    /// several sentences per chunk (rather than one each) is what keeps the
    /// natural cross-sentence flow that made single-sentence chunks sound
    /// choppy, while still cutting time-to-first-audio on longer replies.
    private var pipelineChunks: [Data?] = []
    private var pipelineNextIndex = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Awaits both permission prompts and reports whether Odysseus mode can actually
    /// listen. Callers must wait for this before starting the audio engine —
    /// starting it while permission is still pending is why listening silently
    /// produced no transcript before this fix.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            statusMessage = "Speech recognition access is off. Enable it in Settings → Privacy & Security → Speech Recognition."
            return false
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            statusMessage = "Microphone access is off. Enable it in Settings → Privacy & Security → Microphone."
            return false
        }

        statusMessage = nil
        return true
    }

    func startListening() {
        guard !isListening else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusMessage = "Speech recognition isn't available right now."
            return
        }

        stopSpeaking()
        transcript = ""
        statusMessage = nil

        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Couldn't start the audio session."
            return
        }
        #endif

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // AVAudioEngine.installTap hard-crashes (fatal error, not a throw) if the
        // input format is invalid — which the iOS Simulator's virtual microphone
        // frequently reports as 0 Hz / 0 channels. Guard it instead of finding out
        // via a crash. On a real device this format is always valid.
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            statusMessage = "No microphone input available. This is a common iOS Simulator limitation — voice mode needs a real device."
            #if os(iOS)
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            #endif
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopListening()
                }
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            statusMessage = "Couldn't start listening."
        }
    }

    func stopListening() {
        guard isListening || audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func speak(_ text: String, completion: (() -> Void)? = nil) {
        guard !text.isEmpty else {
            completion?()
            return
        }
        stopSpeaking()
        speechCompletion = completion
        speechToken += 1
        let token = speechToken

        // Three-tier fallback: ElevenLabs (best, most characterful voice)
        // → OpenAI TTS → on-device system voice.
        let hasElevenLabs = KeychainService.shared.loadElevenLabsKey()?.isEmpty == false
            && ElevenLabsSettings.voiceID?.isEmpty == false
        let hasOpenAI = KeychainService.shared.loadOpenAIKey()?.isEmpty == false

        guard hasElevenLabs || hasOpenAI else {
            statusMessage = "No voice provider configured — using the built-in system voice. Add ElevenLabs or a ChatGPT key in AI Settings for the real voice."
            speakLocally(text)
            return
        }

        isSpeaking = true
        let chunks = Self.chunkText(text)
        pipelineChunks = Array(repeating: nil, count: chunks.count)
        pipelineNextIndex = 0

        for (index, chunk) in chunks.enumerated() {
            Task {
                do {
                    let data = try await Self.fetchAudio(for: chunk, preferElevenLabs: hasElevenLabs, hasOpenAIFallback: hasOpenAI)
                    guard token == speechToken else { return }
                    statusMessage = nil
                    pipelineChunks[index] = data
                    advancePipeline(token: token)
                } catch {
                    guard token == speechToken else { return }
                    if index == 0 {
                        // The very first chunk is what the user actually
                        // notices failing — fall back to local voice for the
                        // whole reply rather than a half-cloud/half-local mix.
                        statusMessage = "Cloud voice failed (\(error.localizedDescription)) — using system voice instead."
                        speakLocally(text)
                    } else {
                        // A later chunk failing shouldn't stall the rest of
                        // the reply — mark it empty so playback skips it.
                        pipelineChunks[index] = Data()
                        advancePipeline(token: token)
                    }
                }
            }
        }
    }

    private static func fetchAudio(for text: String, preferElevenLabs: Bool, hasOpenAIFallback: Bool) async throws -> Data {
        if preferElevenLabs {
            do {
                return try await ElevenLabsService.shared.speechAudio(text: text)
            } catch {
                guard hasOpenAIFallback else { throw error }
                return try await OpenAIService.shared.speechAudio(text: text)
            }
        }
        return try await OpenAIService.shared.speechAudio(text: text)
    }

    /// Groups sentences into ~200-character chunks (never splitting a single
    /// sentence) — big enough that each chunk still reads naturally on its
    /// own, small enough that a long reply doesn't have to fully synthesize
    /// before any of it can start playing.
    private static func chunkText(_ text: String, targetLength: Int = 200) -> [String] {
        let sentences = splitIntoSentences(text)
        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            if current.isEmpty {
                current = sentence
            } else if current.count + sentence.count + 1 <= targetLength {
                current += " " + sentence
            } else {
                chunks.append(current)
                current = sentence
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [text] : chunks
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty { sentences.append(remainder) }
        return sentences.isEmpty ? [text] : sentences
    }

    /// Called both when a new chunk finishes fetching and when playback of
    /// the current chunk finishes — whichever happens second is what
    /// actually advances playback, so ordering between the two doesn't matter.
    private func advancePipeline(token: Int) {
        guard token == speechToken else { return }
        guard audioPlayer == nil else { return }
        guard pipelineNextIndex < pipelineChunks.count else {
            finishSpeaking()
            return
        }
        guard let data = pipelineChunks[pipelineNextIndex] else { return }
        pipelineNextIndex += 1
        guard !data.isEmpty, let player = try? AVAudioPlayer(data: data) else {
            advancePipeline(token: token)
            return
        }
        playCloudAudio(player)
    }

    private func playCloudAudio(_ player: AVAudioPlayer) {
        // .spokenAudio (not .voicePrompt) is the mode for natural narrated
        // speech — .voicePrompt applies short-announcement processing/EQ
        // tuned for cutting through noise, which is exactly what made even
        // the real cloud voice sound processed/robotic.
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        player.delegate = self
        audioPlayer = player
        isSpeaking = true
        player.play()
    }

    private func speakLocally(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.maleVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 0.92
        utterance.prefersAssistiveTechnologySettings = false

        // .spokenAudio (not .voicePrompt) preserves natural quality instead
        // of applying short-announcement processing, and routing through
        // .playback instead of leftover .playAndRecord state is what keeps
        // this from sounding thin/telephone-y.
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// The system's default "compact" voices are the flat/robotic-sounding
    /// ones — picking the highest quality tier actually installed (premium,
    /// then enhanced, then default) is what makes this sound natural instead.
    /// Only used as a fallback when no OpenAI key is configured for real TTS.
    private static let maleVoice: AVSpeechSynthesisVoice? = {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        for quality: AVSpeechSynthesisVoiceQuality in [.premium, .enhanced, .default] {
            let atQuality = voices.filter { $0.quality == quality }
            if let male = atQuality.first(where: { $0.gender == .male }) { return male }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }()

    func stopSpeaking() {
        speechToken += 1
        pipelineChunks = []
        pipelineNextIndex = 0
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let audioPlayer, audioPlayer.isPlaying {
            audioPlayer.stop()
        }
        audioPlayer = nil
        isSpeaking = false
    }

    private func finishSpeaking() {
        isSpeaking = false
        audioPlayer = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        let completion = speechCompletion
        speechCompletion = nil
        completion?()
    }
}

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finishSpeaking() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finishSpeaking() }
    }
}

extension VoiceManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.audioPlayer = nil
            self.advancePipeline(token: self.speechToken)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.audioPlayer = nil
            self.advancePipeline(token: self.speechToken)
        }
    }
}
