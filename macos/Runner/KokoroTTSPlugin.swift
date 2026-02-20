import Foundation
import AVFoundation
import FlutterMacOS
import KokoroSwift
import MLX
import MLXUtilsLibrary
import MLXNN

/// British voices available in Kokoro
struct KokoroVoice {
    let id: String
    let name: String
    let gender: String
    let grade: String
    let isDefault: Bool

    func toDictionary() -> [String: Any] {
        return [
            "code": id,
            "name": name,
            "gender": gender,
            "grade": grade,
            "is_default": isDefault
        ]
    }
}

/// Available British voices
let britishVoices: [KokoroVoice] = [
    KokoroVoice(id: "bf_emma", name: "Emma", gender: "female", grade: "B-", isDefault: true),
    KokoroVoice(id: "bf_isabella", name: "Isabella", gender: "female", grade: "C", isDefault: false),
    KokoroVoice(id: "bf_alice", name: "Alice", gender: "female", grade: "D", isDefault: false),
    KokoroVoice(id: "bf_lily", name: "Lily", gender: "female", grade: "D", isDefault: false),
    KokoroVoice(id: "bm_george", name: "George", gender: "male", grade: "C", isDefault: false),
    KokoroVoice(id: "bm_fable", name: "Fable", gender: "male", grade: "C", isDefault: false),
    KokoroVoice(id: "bm_lewis", name: "Lewis", gender: "male", grade: "D+", isDefault: false),
    KokoroVoice(id: "bm_daniel", name: "Daniel", gender: "male", grade: "D", isDefault: false),
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

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getVoices() -> [[String: Any]] {
        return britishVoices.map { $0.toDictionary() }
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
                    for voice in britishVoices {
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

                print("[KokoroTTS] Generating audio for: \(text.prefix(50))...")

                // Generate audio using KokoroSwift - returns ([Float], [MToken]?)
                let (audioSamples, _) = try engine.generateAudio(
                    voice: voiceEmbedding,
                    language: .enGB,
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
                for voice in britishVoices {
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
            let testVoices = ["bf_emma", "bm_george", "bf_isabella"]
            var outputFiles: [String] = []

            for voiceId in testVoices {
                guard let voiceEmbedding = self.voiceEmbeddings[voiceId] else {
                    print("[KokoroTTS] Voice \(voiceId) not found")
                    continue
                }

                do {
                    print("[KokoroTTS] Generating audio with voice: \(voiceId)")
                    let startTime = Date()

                    let (audioSamples, _) = try engine.generateAudio(
                        voice: voiceEmbedding,
                        language: .enGB,
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
