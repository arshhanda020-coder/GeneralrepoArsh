//
//  VoiceManager.swift
//  ArshHabitTracker
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
    private var speechCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Awaits both permission prompts and reports whether Jarvis mode can actually
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

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Couldn't start the audio session."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
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

        let recordingFormat = inputNode.outputFormat(forBus: 0)
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String, completion: (() -> Void)? = nil) {
        guard !text.isEmpty else {
            completion?()
            return
        }
        speechCompletion = completion
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.maleVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 0.92
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private static let maleVoice: AVSpeechSynthesisVoice? = {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        return candidates.first { $0.gender == .male } ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    private func finishSpeaking() {
        isSpeaking = false
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
