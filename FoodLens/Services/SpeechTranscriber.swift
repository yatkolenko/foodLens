import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechTranscriber: NSObject, ObservableObject {
    enum SpeechTranscriberError: LocalizedError {
        case speechRecognizerUnavailable
        case speechRecognitionDenied
        case microphoneDenied
        case audioEngineUnavailable
        case recognitionUnavailable
        case failedToStart

        var errorDescription: String? {
            switch self {
            case .speechRecognizerUnavailable:
                return "Распознавание речи недоступно на этом устройстве."
            case .speechRecognitionDenied:
                return "Доступ к распознаванию речи запрещён. Разрешите его в настройках iPhone."
            case .microphoneDenied:
                return "Доступ к микрофону запрещён. Разрешите его в настройках iPhone."
            case .audioEngineUnavailable:
                return "Не удалось получить доступ к микрофону."
            case .recognitionUnavailable:
                return "Системное распознавание речи сейчас недоступно."
            case .failedToStart:
                return "Не удалось начать диктовку."
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published private(set) var isRecognizerAvailable = true
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var inactivityWatchdogTask: Task<Void, Never>?
    private var lastRecognitionActivityAt: Date?
    private var lastAudioActivityAt: Date?
    private var hasDetectedSpeechAudio = false

    private let silenceAutoStopDelay: TimeInterval = 4.8
    private let fallbackInactivityTimeout: TimeInterval = 20
    private let speechEnergyThreshold: Float = 0.008
    private let watchdogCheckIntervalNanoseconds: UInt64 = 500_000_000

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
            ?? SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.isRecognizerAvailable = self.speechRecognizer?.isAvailable ?? false
        super.init()
        self.speechRecognizer?.delegate = self
    }

    var isSupported: Bool {
        speechRecognizer != nil
    }

    func startTranscribing(contextualStrings: [String] = []) async throws {
        errorMessage = nil
        transcript = ""

        guard let speechRecognizer else {
            throw SpeechTranscriberError.speechRecognizerUnavailable
        }

        guard speechRecognizer.isAvailable else {
            throw SpeechTranscriberError.recognitionUnavailable
        }

        let speechAuthorized = await requestSpeechPermission()
        guard speechAuthorized else {
            throw SpeechTranscriberError.speechRecognitionDenied
        }

        let microphoneAuthorized = await requestMicrophonePermission()
        guard microphoneAuthorized else {
            throw SpeechTranscriberError.microphoneDenied
        }

        stopTranscribing(resetTranscript: false)
        inactivityWatchdogTask?.cancel()
        inactivityWatchdogTask = nil
        lastRecognitionActivityAt = Date()
        lastAudioActivityAt = nil
        hasDetectedSpeechAudio = false

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechTranscriberError.audioEngineUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = contextualStrings
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let speechThreshold = speechEnergyThreshold
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            guard Self.audioLevel(in: buffer) >= speechThreshold else { return }
            Task { @MainActor [weak self] in
                self?.lastAudioActivityAt = Date()
                self?.hasDetectedSpeechAudio = true
            }
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    self.lastRecognitionActivityAt = Date()
                }
            }

            if let error {
                Task { @MainActor in
                    if self.isRecording {
                        self.stopTranscribing(resetTranscript: false)
                    }
                    let nsError = error as NSError
                    if nsError.code != 301 && nsError.code != 216 {
                        self.errorMessage = "Не удалось завершить диктовку. Попробуйте ещё раз."
                    }
                }
                return
            }

            if result?.isFinal == true {
                Task { @MainActor in
                    self.stopTranscribing(resetTranscript: false)
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            startInactivityWatchdog()
        } catch {
            stopTranscribing(resetTranscript: false)
            throw SpeechTranscriberError.failedToStart
        }
    }

    func stopTranscribing(resetTranscript: Bool = false) {
        inactivityWatchdogTask?.cancel()
        inactivityWatchdogTask = nil
        lastRecognitionActivityAt = nil
        lastAudioActivityAt = nil
        hasDetectedSpeechAudio = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        if resetTranscript {
            transcript = ""
        }
    }

    private func startInactivityWatchdog() {
        inactivityWatchdogTask?.cancel()
        inactivityWatchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.watchdogCheckIntervalNanoseconds ?? 500_000_000)
                guard let self, self.isRecording else { return }
                let now = Date()

                let latestSpeechSignalAt = [self.lastAudioActivityAt, self.lastRecognitionActivityAt]
                    .compactMap { $0 }
                    .max()

                if self.hasDetectedSpeechAudio,
                   let latestSpeechSignalAt,
                   now.timeIntervalSince(latestSpeechSignalAt) >= silenceAutoStopDelay {
                    self.stopTranscribing(resetTranscript: false)
                    return
                }

                guard let lastRecognitionActivityAt else { continue }
                let inactivityDuration = now.timeIntervalSince(lastRecognitionActivityAt)
                if inactivityDuration >= fallbackInactivityTimeout {
                    self.stopTranscribing(resetTranscript: false)
                    return
                }
            }
        }
    }

    nonisolated private static func audioLevel(in buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channels = buffer.floatChannelData {
            let samples = channels[0]
            var sum: Float = 0
            for index in 0..<frameLength {
                let sample = samples[index]
                sum += sample * sample
            }
            return sqrt(sum / Float(frameLength))
        }

        if let channels = buffer.int16ChannelData {
            let samples = channels[0]
            var sum: Float = 0
            for index in 0..<frameLength {
                let normalized = Float(samples[index]) / Float(Int16.max)
                sum += normalized * normalized
            }
            return sqrt(sum / Float(frameLength))
        }

        if let channels = buffer.int32ChannelData {
            let samples = channels[0]
            var sum: Float = 0
            for index in 0..<frameLength {
                let normalized = Float(samples[index]) / Float(Int32.max)
                sum += normalized * normalized
            }
            return sqrt(sum / Float(frameLength))
        }

        return 0
    }

    private func requestSpeechPermission() async -> Bool {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()

        switch currentStatus {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
}

extension SpeechTranscriber: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.isRecognizerAvailable = available
        }
    }
}
