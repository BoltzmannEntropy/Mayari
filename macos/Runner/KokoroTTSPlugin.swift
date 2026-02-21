import Foundation
import AVFoundation
import FlutterMacOS
import PDFKit
import KokoroSwift
import MLX
import MLXUtilsLibrary
import MLXNN

/// Kokoro voice metadata for UI and language routing.
struct KokoroVoice {
    let id: String
    let name: String
    let gender: String
    let grade: String
    let language: Language
    let isDefault: Bool

    func toDictionary() -> [String: Any] {
        return [
            "code": id,
            "name": name,
            "gender": gender,
            "grade": grade,
            "language_code": language.rawValue,
            "language_name": language == .enUS ? "English (US)" : "English (UK)",
            "is_default": isDefault
        ]
    }
}

/// Available Kokoro English voices from voices.npz.
let kokoroVoices: [KokoroVoice] = [
    KokoroVoice(id: "af_alloy", name: "Alloy", gender: "female", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_aoede", name: "Aoede", gender: "female", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_bella", name: "Bella", gender: "female", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_heart", name: "Heart", gender: "female", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_jessica", name: "Jessica", gender: "female", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_kore", name: "Kore", gender: "female", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_nicole", name: "Nicole", gender: "female", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_nova", name: "Nova", gender: "female", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_river", name: "River", gender: "female", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_sarah", name: "Sarah", gender: "female", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "af_sky", name: "Sky", gender: "female", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_adam", name: "Adam", gender: "male", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_echo", name: "Echo", gender: "male", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_eric", name: "Eric", gender: "male", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_fenrir", name: "Fenrir", gender: "male", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_liam", name: "Liam", gender: "male", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_michael", name: "Michael", gender: "male", grade: "B", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_onyx", name: "Onyx", gender: "male", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_puck", name: "Puck", gender: "male", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "am_santa", name: "Santa", gender: "male", grade: "C", language: .enUS, isDefault: false),
    KokoroVoice(id: "bf_emma", name: "Emma", gender: "female", grade: "B-", language: .enGB, isDefault: true),
    KokoroVoice(id: "bf_isabella", name: "Isabella", gender: "female", grade: "C", language: .enGB, isDefault: false),
    KokoroVoice(id: "bf_alice", name: "Alice", gender: "female", grade: "D", language: .enGB, isDefault: false),
    KokoroVoice(id: "bf_lily", name: "Lily", gender: "female", grade: "D", language: .enGB, isDefault: false),
    KokoroVoice(id: "bm_george", name: "George", gender: "male", grade: "C", language: .enGB, isDefault: false),
    KokoroVoice(id: "bm_fable", name: "Fable", gender: "male", grade: "C", language: .enGB, isDefault: false),
    KokoroVoice(id: "bm_lewis", name: "Lewis", gender: "male", grade: "D+", language: .enGB, isDefault: false),
    KokoroVoice(id: "bm_daniel", name: "Daniel", gender: "male", grade: "D", language: .enGB, isDefault: false),
]

/// TTS Plugin for Flutter using KokoroSwift
@available(macOS 15.0, *)
class KokoroTTSPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var audioPlayer: AVAudioPlayer?
    private let audioQueue = DispatchQueue(label: "com.mayari.tts.audio", qos: .userInitiated)

    private var ttsEngine: KokoroTTS?
    private var voiceEmbeddings: [String: MLXArray] = [:]
    private var isModelLoaded = false
    private var isLoading = false

    private func languageForVoiceId(_ voiceId: String) -> Language {
        if let voice = kokoroVoices.first(where: { $0.id == voiceId }) {
            return voice.language
        }
        return .enGB
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.mayari.tts",
            binaryMessenger: registrar.messenger
        )
        let instance = KokoroTTSPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("[KokoroTTS] Plugin registered with KokoroSwift")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true)

        case "loadModel":
            loadModel(result: result)

        case "getVoices":
            result(getVoices())

        case "speak":
            guard let args = call.arguments as? [String: Any],
                  let text = args["text"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing text argument", details: nil))
                return
            }
            let voice = args["voice"] as? String ?? "bf_emma"
            let speed = args["speed"] as? Double ?? 1.0
            speak(text: text, voice: voice, speed: speed, result: result)

        case "pause":
            audioPlayer?.pause()
            result(true)

        case "resume":
            audioPlayer?.play()
            result(true)

        case "stop":
            audioPlayer?.stop()
            audioPlayer = nil
            result(true)

        case "isPlaying":
            result(audioPlayer?.isPlaying ?? false)

        case "getModelStatus":
            result([
                "loaded": isModelLoaded,
                "loading": isLoading,
                "available": true,
                "engine": "KokoroSwift"
            ])

        case "testVoices":
            testVoices(result: result)

        case "generateAudiobook":
            guard let args = call.arguments as? [String: Any],
                  let chunks = args["chunks"] as? [String],
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing chunks or outputPath", details: nil))
                return
            }
            let voice = args["voice"] as? String ?? "bf_emma"
            let speed = args["speed"] as? Double ?? 1.0
            let title = args["title"] as? String ?? "Audiobook"
            let requestId = args["requestId"] as? String ?? UUID().uuidString
            generateAudiobook(
                chunks: chunks,
                voice: voice,
                speed: speed,
                title: title,
                outputPath: outputPath,
                requestId: requestId,
                result: result
            )

        case "extractPdfText":
            guard let args = call.arguments as? [String: Any],
                  let bytes = args["bytes"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing PDF bytes", details: nil))
                return
            }
            let startPage = args["startPage"] as? Int ?? 1
            extractPdfText(pdfBytes: bytes.data, startPage: startPage, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getVoices() -> [[String: Any]] {
        return kokoroVoices.map { $0.toDictionary() }
    }

    private func getModelDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mayariDir = appSupport.appendingPathComponent("Mayari")
        let modelDir = mayariDir.appendingPathComponent("kokoro-model")

        try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        return modelDir
    }

    private func loadModel(result: @escaping FlutterResult) {
        if isModelLoaded {
            result(true)
            return
        }

        if isLoading {
            result(FlutterError(code: "LOADING", message: "Model is already loading", details: nil))
            return
        }

        isLoading = true

        audioQueue.async { [weak self] in
            guard let self = self else { return }

            let modelDir = self.getModelDirectory()
            let modelPath = modelDir.appendingPathComponent("kokoro-v1_0.safetensors")
            let voicesPath = modelDir.appendingPathComponent("voices.npz")

            // Check if model exists
            if !FileManager.default.fileExists(atPath: modelPath.path) {
                DispatchQueue.main.async {
                    self.isLoading = false
                    result(FlutterError(
                        code: "MODEL_NOT_FOUND",
                        message: "Model not found. Please download the Kokoro model first.",
                        details: modelDir.path
                    ))
                }
                return
            }

            // Initialize TTS engine with Misaki G2P (non-throwing)
            print("[KokoroTTS] Loading model from: \(modelPath.path)")
            self.ttsEngine = KokoroTTS(modelPath: modelPath, g2p: .misaki)

            // Load voice embeddings from NPZ file
            if FileManager.default.fileExists(atPath: voicesPath.path) {
                print("[KokoroTTS] Loading voice embeddings from: \(voicesPath.path)")
                if let voiceData = NpyzReader.read(fileFromPath: voicesPath) {
                    for voice in kokoroVoices {
                        // NPZ entries have .npy extension in their keys
                        let key = "\(voice.id).npy"
                        if let embedding = voiceData[key] {
                            self.voiceEmbeddings[voice.id] = embedding
                            print("[KokoroTTS] Loaded voice: \(voice.id)")
                        }
                    }
                }
            } else {
                print("[KokoroTTS] No voices.npz found at: \(voicesPath.path)")
            }

            self.isModelLoaded = true
            self.isLoading = false

            DispatchQueue.main.async {
                print("[KokoroTTS] Model loaded successfully")
                result(true)
            }
        }
    }

    private func speak(text: String, voice: String, speed: Double, result: @escaping FlutterResult) {
        guard isModelLoaded, let engine = ttsEngine else {
            result(FlutterError(code: "NOT_LOADED", message: "Model not loaded. Call loadModel first.", details: nil))
            return
        }

        audioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // Get voice embedding, fallback to emma
                guard let voiceEmbedding = self.voiceEmbeddings[voice] ?? self.voiceEmbeddings["bf_emma"] else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "VOICE_ERROR", message: "No voice embedding found for \(voice)", details: nil))
                    }
                    return
                }
                let language = self.languageForVoiceId(voice)

                print("[KokoroTTS] Generating audio for: \(text.prefix(50))...")

                // Generate audio using KokoroSwift - returns ([Float], [MToken]?)
                let (audioSamples, _) = try engine.generateAudio(
                    voice: voiceEmbedding,
                    language: language,
                    text: text,
                    speed: Float(speed)
                )

                // Convert to WAV and play - use constant sample rate 24000
                let wavData = self.convertToWav(samples: audioSamples, sampleRate: KokoroTTS.Constants.samplingRate)

                DispatchQueue.main.async {
                    do {
                        self.audioPlayer = try AVAudioPlayer(data: wavData)
                        self.audioPlayer?.prepareToPlay()
                        self.audioPlayer?.play()
                        print("[KokoroTTS] Playing audio...")
                        result(true)
                    } catch {
                        print("[KokoroTTS] Playback error: \(error)")
                        result(FlutterError(code: "PLAYBACK_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("[KokoroTTS] Generate error: \(error)")
                    result(FlutterError(code: "GENERATE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    /// Test method to generate WAV files with 3 different voices
    private func testVoices(result: @escaping FlutterResult) {
        // First ensure model is loaded
        if !isModelLoaded {
            // Load model synchronously for test
            let modelDir = getModelDirectory()
            let modelPath = modelDir.appendingPathComponent("kokoro-v1_0.safetensors")
            let voicesPath = modelDir.appendingPathComponent("voices.npz")

            if !FileManager.default.fileExists(atPath: modelPath.path) {
                result(FlutterError(code: "MODEL_NOT_FOUND", message: "Model not found", details: nil))
                return
            }

            print("[KokoroTTS] Loading model for test...")
            ttsEngine = KokoroTTS(modelPath: modelPath, g2p: .misaki)

            if let voiceData = NpyzReader.read(fileFromPath: voicesPath) {
                for voice in kokoroVoices {
                    let key = "\(voice.id).npy"
                    if let embedding = voiceData[key] {
                        voiceEmbeddings[voice.id] = embedding
                    }
                }
            }
            isModelLoaded = true
            print("[KokoroTTS] Model loaded for test")
        }

        guard let engine = ttsEngine else {
            result(FlutterError(code: "ENGINE_ERROR", message: "Engine not initialized", details: nil))
            return
        }

        audioQueue.async { [weak self] in
            guard let self = self else { return }

            let testText = "Hello! This is a test of the Kokoro text to speech engine running natively on macOS with no Python required."
            let testVoices = ["bf_emma", "af_heart", "am_liam"]
            var outputFiles: [String] = []

            for voiceId in testVoices {
                guard let voiceEmbedding = self.voiceEmbeddings[voiceId] else {
                    print("[KokoroTTS] Voice \(voiceId) not found")
                    continue
                }

                do {
                    print("[KokoroTTS] Generating audio with voice: \(voiceId)")
                    let startTime = Date()
                    let language = self.languageForVoiceId(voiceId)

                    let (audioSamples, _) = try engine.generateAudio(
                        voice: voiceEmbedding,
                        language: language,
                        text: testText,
                        speed: 1.0
                    )

                    let duration = Date().timeIntervalSince(startTime)
                    print("[KokoroTTS] Generated \(audioSamples.count) samples in \(String(format: "%.2f", duration))s")

                    let wavData = self.convertToWav(samples: audioSamples, sampleRate: KokoroTTS.Constants.samplingRate)

                    // Save to sandbox Documents folder
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let outputPath = docs.appendingPathComponent("kokoro_test_\(voiceId).wav")
                    try wavData.write(to: outputPath)
                    print("[KokoroTTS] Saved: \(outputPath.path)")
                    outputFiles.append(outputPath.path)

                } catch {
                    print("[KokoroTTS] Error generating with \(voiceId): \(error)")
                }
            }

            DispatchQueue.main.async {
                result(outputFiles)
            }
        }
    }

    /// Generate a complete audiobook from text chunks
    private func generateAudiobook(
        chunks: [String],
        voice: String,
        speed: Double,
        title: String,
        outputPath: String,
        requestId: String,
        result: @escaping FlutterResult
    ) {
        guard isModelLoaded, let engine = ttsEngine else {
            result(FlutterError(code: "NOT_LOADED", message: "Model not loaded", details: nil))
            return
        }

        guard let voiceEmbedding = voiceEmbeddings[voice] ?? voiceEmbeddings["bf_emma"] else {
            result(FlutterError(code: "VOICE_ERROR", message: "Voice not found", details: nil))
            return
        }
        let language = languageForVoiceId(voice)

        audioQueue.async { [weak self] in
            guard let self = self else { return }

            var allSamples: [Float] = []
            let totalChunks = chunks.count
            let silenceSamples = [Float](repeating: 0, count: KokoroTTS.Constants.samplingRate / 2) // 0.5s silence between chunks

            for (index, chunk) in chunks.enumerated() {
                let trimmedChunk = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedChunk.isEmpty else { continue }

                // Report progress
                DispatchQueue.main.async {
                    self.methodChannel?.invokeMethod("audiobookProgress", arguments: [
                        "requestId": requestId,
                        "current": index + 1,
                        "total": totalChunks,
                        "status": "Processing chunk \(index + 1) of \(totalChunks)"
                    ])
                }

                do {
                    print("[KokoroTTS] Generating chunk \(index + 1)/\(totalChunks): \(trimmedChunk.prefix(50))...")

                    let (audioSamples, _) = try engine.generateAudio(
                        voice: voiceEmbedding,
                        language: language,
                        text: trimmedChunk,
                        speed: Float(speed)
                    )

                    allSamples.append(contentsOf: audioSamples)

                    // Add silence between chunks (except after last)
                    if index < totalChunks - 1 {
                        allSamples.append(contentsOf: silenceSamples)
                    }

                } catch {
                    print("[KokoroTTS] Error on chunk \(index): \(error)")
                    // Continue with next chunk
                }
            }

            if allSamples.isEmpty {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GENERATE_ERROR", message: "No audio samples generated", details: nil))
                }
                return
            }

            // Convert to WAV
            let wavData = self.convertToWav(samples: allSamples, sampleRate: KokoroTTS.Constants.samplingRate)

            // Save to file
            do {
                let outputURL = URL(fileURLWithPath: outputPath)
                try wavData.write(to: outputURL)

                let durationSeconds = Double(allSamples.count) / Double(KokoroTTS.Constants.samplingRate)

                DispatchQueue.main.async {
                    print("[KokoroTTS] Audiobook saved: \(outputPath) (\(String(format: "%.1f", durationSeconds))s)")
                    result([
                        "path": outputPath,
                        "duration": durationSeconds,
                        "chunks": totalChunks,
                        "format": "wav"
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func extractPdfText(pdfBytes: Data, startPage: Int, result: @escaping FlutterResult) {
        audioQueue.async {
            guard let document = PDFDocument(data: pdfBytes) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "PDF_ERROR", message: "Failed to read PDF bytes", details: nil))
                }
                return
            }

            let pageCount = document.pageCount
            if pageCount <= 0 {
                DispatchQueue.main.async { result("") }
                return
            }

            let clampedStart = max(0, min(pageCount - 1, startPage - 1))
            var pages: [String] = []
            for pageIndex in clampedStart..<pageCount {
                guard let page = document.page(at: pageIndex),
                      let pageText = page.string else {
                    continue
                }
                let normalizedPage = self.normalizeExtractedPdfText(pageText)
                if !normalizedPage.isEmpty {
                    pages.append(normalizedPage)
                }
            }

            let combined = self.normalizeExtractedPdfText(pages.joined(separator: "\n\n"))
            DispatchQueue.main.async {
                result(combined)
            }
        }
    }

    private func normalizeExtractedPdfText(_ text: String) -> String {
        if text.isEmpty {
            return text
        }

        var normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\r", with: "\n")
        normalized = normalized.replacingOccurrences(
            of: "(?<!\\n)\\n(?!\\n)",
            with: " ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: "([.!?;:,])(?=[A-Za-z])",
            with: "$1 ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: "(?<=[a-z])(?=[A-Z])",
            with: " ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convertToWav(samples: [Float], sampleRate: Int) -> Data {
        var data = Data()

        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // Convert float samples to int16
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16Value = Int16(clamped * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: int16Value.littleEndian) { Array($0) })
        }

        return data
    }
}
