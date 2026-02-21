# Mayari vs Speechify: Deep Feature Comparison

**Last Updated:** 2026-02-21
**Version:** 1.0

## Executive Summary

| Category | Mayari | Speechify |
|----------|--------|-----------|
| **Core Focus** | PDF reading + audiobook generation | Full voice AI productivity suite |
| **Voices** | 8 (Kokoro British) | 1,000+ in 60+ languages |
| **Price** | Free/Open source | Freemium ($139-288/yr) |
| **Platform** | macOS only | iOS, Android, Web, Desktop |
| **AI Features** | TTS only | Full AI assistant suite |

---

## Table of Contents

1. [Detailed Feature Comparison](#detailed-feature-comparison)
2. [What Mayari Does Better](#what-mayari-does-better)
3. [Missing Features Priority List](#missing-features-priority-list)
4. [LLM Models for Swift/Flutter](#llm-models-available-for-swiftflutter)
5. [Recommended Roadmap](#recommended-roadmap-for-mayari)
6. [Sources](#sources)

---

## Detailed Feature Comparison

### 1. Text-to-Speech Voices

| Feature | Mayari | Speechify | Gap |
|---------|--------|-----------|-----|
| Voice count | 8 voices | 1,000+ voices | :x: **Major gap** |
| Languages | English (British) only | 60+ languages | :x: **Major gap** |
| Celebrity voices | None | Snoop Dogg, Gwyneth Paltrow, etc. | :x: Missing |
| Voice emotions | None | 10+ emotions per voice | :x: Missing |
| Voice cloning | None | 20-second clone creation | :x: **Major gap** |
| Custom voice training | None | Yes | :x: Missing |

**Mayari's Current Voices:**
- **Female**: Emma (B-), Isabella (C), Alice (D), Lily (D)
- **Male**: George (C), Fable (C), Lewis (D+), Daniel (D)

### 2. Document Support

| Feature | Mayari | Speechify | Gap |
|---------|--------|-----------|-----|
| PDF support | :white_check_mark: Full | :white_check_mark: Full | :white_check_mark: Parity |
| EPUB support | :x: No | :white_check_mark: Yes | :x: Missing |
| DOCX support | :x: No | :white_check_mark: Yes | :x: Missing |
| XLSX support | :x: No | :white_check_mark: Yes | :x: Missing |
| TXT support | :white_check_mark: Via Markdown | :white_check_mark: Yes | :white_check_mark: Parity |
| Web pages | :x: No | :white_check_mark: Browser extension | :x: Missing |
| OCR scanning | :x: No | :white_check_mark: Photo-to-text | :x: **Major gap** |
| Cloud sync | :x: No | :white_check_mark: Cross-device | :x: Missing |
| Offline reading | :white_check_mark: Full | :white_check_mark: Premium only | :white_check_mark: **Advantage** |

### 3. AI & Intelligence Features

| Feature | Mayari | Speechify | Gap |
|---------|--------|-----------|-----|
| AI Podcast generation | :x: No | :white_check_mark: Full (debates, lectures, conversations) | :x: **Major gap** |
| AI Summarization | :x: No | :white_check_mark: Instant summaries | :x: **Major gap** |
| AI Q&A about content | :x: No | :white_check_mark: Context-aware answers | :x: **Major gap** |
| Quiz generation | :x: No | :white_check_mark: From reading material | :x: Missing |
| Voice typing/dictation | :x: No | :white_check_mark: With grammar correction | :x: Missing |
| AI note-taking | :x: No | :white_check_mark: Full | :x: Missing |
| Meeting assistant | :x: No | :white_check_mark: Transcription + notes | :x: Missing |
| Content recaps | :x: No | :white_check_mark: When returning to material | :x: Missing |

### 4. Video & Media Features

| Feature | Mayari | Speechify | Gap |
|---------|--------|-----------|-----|
| AI Dubbing | :x: No | :white_check_mark: 100+ languages | :x: **Major gap** |
| AI Avatars | :x: No | :white_check_mark: Hundreds available | :x: **Major gap** |
| Video voiceover | :x: No | :white_check_mark: Studio integration | :x: Missing |
| Translation | :x: No | :white_check_mark: 60+ languages | :x: **Major gap** |
| Voice preservation dubbing | :x: No | :white_check_mark: Keep original voice tone | :x: Missing |
| Video export | :x: No | :white_check_mark: Multiple formats | :x: Missing |

### 5. Audio Output Features

| Feature | Mayari | Speechify | Status |
|---------|--------|-----------|--------|
| Audiobook generation | :white_check_mark: Full | :white_check_mark: Full | :white_check_mark: Parity |
| WAV export | :white_check_mark: Direct | :white_check_mark: Via Studio | :white_check_mark: Parity |
| MP3 export | :x: No | :white_check_mark: Yes | :x: Missing |
| Batch processing | :white_check_mark: Job queue | :white_check_mark: Yes | :white_check_mark: Parity |
| Speed control | :white_check_mark: 0.5x-2.0x | :white_check_mark: Up to 4.5x | :yellow_circle: Partial |
| Playback controls | :white_check_mark: Full | :white_check_mark: Full | :white_check_mark: Parity |

### 6. Platform & Integration

| Feature | Mayari | Speechify | Gap |
|---------|--------|-----------|-----|
| macOS | :white_check_mark: Native (15.0+) | :white_check_mark: Native | :white_check_mark: Parity |
| iOS/iPad | :yellow_circle: Build exists | :white_check_mark: Full | :yellow_circle: Partial |
| Android | :x: No | :white_check_mark: Full | :x: Missing |
| Web app | :x: No | :white_check_mark: Full | :x: Missing |
| Browser extension | :x: No | :white_check_mark: Chrome/Edge | :x: Missing |
| API access | :x: No | :white_check_mark: $10/1M chars | :x: Missing |
| Offline mode | :white_check_mark: Full | :white_check_mark: Premium only | :white_check_mark: **Advantage** |

### 7. User Experience

| Feature | Mayari | Speechify | Status |
|---------|--------|-----------|--------|
| Text highlighting | :white_check_mark: Word-level | :white_check_mark: Word-level | :white_check_mark: Parity |
| Keyboard shortcuts | :white_check_mark: Cmd+D, Space, Esc | :white_check_mark: Various | :white_check_mark: Parity |
| Dark mode | :white_check_mark: System | :white_check_mark: Yes | :white_check_mark: Parity |
| Quote extraction | :white_check_mark: Full | :x: No | :white_check_mark: **Advantage** |
| Citation formatting | :white_check_mark: Academic | :x: No | :white_check_mark: **Advantage** |

---

## What Mayari Does Better

| Feature | Mayari Advantage | Details |
|---------|------------------|---------|
| **Privacy** | 100% offline | No data leaves device, no telemetry |
| **Cost** | Completely free | No subscription, no limits |
| **Audiobook export** | Direct WAV export | No credits, no restrictions |
| **Open source** | Fully customizable | Extend and modify freely |
| **No account required** | Works immediately | No sign-up, no login |
| **Native performance** | MLX Metal acceleration | Optimized for Apple Silicon |
| **Quote extraction** | Built-in | Academic citation support |
| **Offline-first** | Full functionality | No internet required after setup |

---

## Missing Features Priority List

### :red_circle: Critical (High Impact)

| Priority | Feature | Effort | Impact | Notes |
|----------|---------|--------|--------|-------|
| 1 | **Voice Cloning** | High | Very High | Speechify's killer feature |
| 2 | **AI Podcast Generation** | High | Very High | Document-to-podcast, multiple formats |
| 3 | **More Voices** | Medium | High | Need 50+ voices minimum |
| 4 | **Multi-language TTS** | High | High | At least 10 major languages |
| 5 | **OCR Scanning** | Medium | High | Photo-to-text reading |

### :yellow_circle: Important (Medium Impact)

| Priority | Feature | Effort | Impact | Notes |
|----------|---------|--------|--------|-------|
| 6 | **AI Summarization** | Medium | Medium | Quick document summaries |
| 7 | **AI Q&A** | Medium | Medium | Ask questions about content |
| 8 | **Voice Typing** | Medium | Medium | Dictation with transcription |
| 9 | **EPUB/DOCX support** | Low | Medium | More document formats |
| 10 | **Browser extension** | High | Medium | Read web pages |

### :green_circle: Nice to Have

| Priority | Feature | Effort | Impact | Notes |
|----------|---------|--------|--------|-------|
| 11 | AI Avatars | Very High | Low | Video generation |
| 12 | AI Dubbing | Very High | Low | Video translation |
| 13 | Quiz generation | Medium | Low | Learning tools |
| 14 | Cloud sync | High | Medium | Cross-device |
| 15 | Meeting assistant | High | Low | Transcription |

---

## LLM Models Available for Swift/Flutter

### For macOS (MLX Framework)

| Model | Size | RAM Needed | Use Case | Speed (M3) | Link |
|-------|------|------------|----------|------------|------|
| **Qwen3-8B-4bit** | 4.3 GB | 8 GB | Chat & reasoning | ~35 tok/s | [HuggingFace](https://huggingface.co/mlx-community) |
| **Qwen3-4B-4bit** | ~2 GB | 6 GB | Lightweight chat | ~50 tok/s | [Qwen Docs](https://qwen.readthedocs.io/en/latest/run_locally/mlx-lm.html) |
| **Llama-3.2-1B-4bit** | 0.8 GB | 4 GB | Ultra-fast, low RAM | ~80 tok/s | [Swama](https://github.com/Trans-N-ai/swama) |
| **Llama-3.2-3B-4bit** | ~1.8 GB | 6 GB | Mobile-friendly | ~60 tok/s | [mlx-lm](https://github.com/ml-explore/mlx-lm) |
| **Gemma-3-4B-4bit** | 3.2 GB | 8 GB | Vision + text | ~40 tok/s | [Swama](https://github.com/Trans-N-ai/swama) |
| **Phi-4-14B-4bit** | ~8 GB | 16 GB | High quality | ~25 tok/s | [BrightCoding](https://www.blog.brightcoding.dev/2025/07/18/run-local-llms-at-blazing-speed-on-your-mac-with-swift-and-mlx/) |
| **DeepSeek-R1-Qwen3-8B** | 4.3 GB | 8 GB | Step-by-step reasoning | ~30 tok/s | [Swama](https://github.com/Trans-N-ai/swama) |
| **Mistral-7B-4bit** | ~4 GB | 8 GB | General purpose | ~35 tok/s | [LLM.swift](https://github.com/eastriverlee/LLM.swift) |

### For iOS/Mobile

| Model | Size | Framework | Min Device | Notes |
|-------|------|-----------|------------|-------|
| **Qwen3-1.5B** | ~1 GB | mlx-swift | iPhone 12+ | WWDC25 featured |
| **TinyLlama-1.1B** | ~0.6 GB | llm_llamacpp | iPhone 11+ | Flutter compatible |
| **Phi-3-mini** | ~2 GB | LLM.swift | iPhone 13+ | iOS/watchOS/visionOS |
| **Gemma-2B** | ~1.5 GB | mlx-swift | iPhone 12+ | Good for mobile |

### Swift Frameworks Comparison

| Framework | Maintainer | Platforms | Features | Best For |
|-----------|------------|-----------|----------|----------|
| **[mlx-swift](https://github.com/ml-explore/mlx-swift)** | Apple | macOS, iOS | Official, optimized | Production apps |
| **[mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples)** | Apple | macOS, iOS | Chat app, LLMEval | Learning/Reference |
| **[Swama](https://github.com/Trans-N-ai/swama)** | Community | macOS | Menu bar, OpenAI API | Quick integration |
| **[LLM.swift](https://github.com/eastriverlee/LLM.swift)** | Community | All Apple | Simple, llama.cpp | Prototyping |

### Flutter Packages

| Package | Backend | Platforms | Notes |
|---------|---------|-----------|-------|
| **[llm_llamacpp](https://pub.dev/packages/llm_llamacpp)** | llama.cpp | All | GGUF models, on-device |
| **ollama_dart** | Ollama | All | Requires Ollama server |

### Performance by Apple Silicon

| Chip | Qwen3-8B-4bit | Phi-4-14B-4bit | Llama-3.2-1B |
|------|---------------|----------------|--------------|
| M1 | ~20 tok/s | ~10 tok/s | ~60 tok/s |
| M1 Pro | ~28 tok/s | ~15 tok/s | ~70 tok/s |
| M2 | ~25 tok/s | ~12 tok/s | ~65 tok/s |
| M3 | ~35 tok/s | ~25 tok/s | ~80 tok/s |
| M3 Pro | ~42 tok/s | ~32 tok/s | ~90 tok/s |
| M3 Max | ~50 tok/s | ~41 tok/s | ~100 tok/s |
| M4 | ~40 tok/s | ~30 tok/s | ~85 tok/s |

---

## Recommended Roadmap for Mayari

### Phase 1: Core Voice Improvements (Q1)

| Task | Description | Effort | Dependencies |
|------|-------------|--------|--------------|
| 1.1 | Add more Kokoro voices (if available) | Low | None |
| 1.2 | Implement voice emotions (speed/pitch variation) | Medium | None |
| 1.3 | Add playback speed up to 4x | Low | None |
| 1.4 | MP3 export option | Low | None |

### Phase 2: AI Features via Local LLM (Q2)

| Task | Description | Effort | Dependencies |
|------|-------------|--------|--------------|
| 2.1 | Integrate mlx-swift with Qwen3-4B | Medium | mlx-swift |
| 2.2 | **AI Summarization** - document summaries | Medium | 2.1 |
| 2.3 | **AI Q&A** - ask questions about content | Medium | 2.1 |
| 2.4 | **AI Podcast Generation** - two-voice conversations | High | 2.1, more voices |

**Suggested LLM Integration Architecture:**
```
┌─────────────────────────────────────────────┐
│                  Mayari App                  │
├─────────────────────────────────────────────┤
│  PDF Reader  │  TTS Engine  │  AI Features  │
│              │  (Kokoro)    │  (Qwen3-4B)   │
├─────────────────────────────────────────────┤
│              MLX Swift Framework             │
├─────────────────────────────────────────────┤
│              Apple Silicon GPU               │
└─────────────────────────────────────────────┘
```

### Phase 3: Document & Platform Expansion (Q3)

| Task | Description | Effort | Dependencies |
|------|-------------|--------|--------------|
| 3.1 | OCR via Apple Vision framework | Medium | None |
| 3.2 | EPUB support | Medium | None |
| 3.3 | DOCX support | Medium | None |
| 3.4 | Complete iOS app | High | None |

### Phase 4: Advanced Features (Q4+)

| Task | Description | Effort | Dependencies |
|------|-------------|--------|--------------|
| 4.1 | Voice cloning research | Very High | Training infra |
| 4.2 | Multi-language TTS | Very High | Voice models |
| 4.3 | Browser extension | High | Web expertise |
| 4.4 | Cloud sync (optional) | High | Backend infra |

---

## Implementation Notes

### Adding Qwen3 to Mayari

```swift
// Package.swift dependencies
.package(url: "https://github.com/ml-explore/mlx-swift", branch: "main"),
.package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"),

// Basic usage
import MLXLLM

let model = try await LLM.load(from: "mlx-community/Qwen3-4B-Instruct-4bit")
let response = try await model.generate(prompt: "Summarize this text: ...")
```

### Podcast Generation Concept

```
Input: PDF document text
↓
Step 1: Extract key points via Qwen3
↓
Step 2: Generate conversational script (Host A + Host B)
↓
Step 3: Synthesize with two different Kokoro voices
↓
Step 4: Mix audio with transitions
↓
Output: Podcast MP3/WAV
```

---

## Sources

### Speechify
- [Speechify Official](https://speechify.com/)
- [Speechify AI Expansion News](https://speechify.com/news/speechify-expands-voice-ai-assistant-text-to-speech/)
- [Speechify Studio Pricing](https://speechify.com/pricing-studio/)
- [Speechify Voice Cloning](https://speechify.com/voice-cloning/)
- [Speechify AI Dubbing](https://speechify.com/blog/real-time-ai-dubbing/)

### LLM & ML Frameworks
- [mlx-swift GitHub](https://github.com/ml-explore/mlx-swift)
- [mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples)
- [Qwen3 MLX Documentation](https://qwen.readthedocs.io/en/latest/run_locally/mlx-lm.html)
- [Qwen3 GitHub](https://github.com/QwenLM/Qwen3)
- [Swama - MLX LLM Engine](https://github.com/Trans-N-ai/swama)
- [WWDC25 MLX Session](https://developer.apple.com/videos/play/wwdc2025/298/)
- [Apple MLX Research](https://machinelearning.apple.com/research/exploring-llms-mlx-m5)

### Swift/Flutter LLM Libraries
- [LLM.swift](https://github.com/eastriverlee/LLM.swift)
- [llm_llamacpp Flutter](https://pub.dev/packages/llm_llamacpp)
- [MLX Community HuggingFace](https://huggingface.co/mlx-community)

### Reviews & Comparisons
- [Speechify Review - SkyWork](https://skywork.ai/blog/speechify-review/)
- [Speechify Review - FahimAI](https://www.fahimai.com/speechify)
- [Local LLMs on Mobile - Callstack](https://www.callstack.com/blog/local-llms-on-mobile-are-a-gimmick)

---

*Document generated for Mayari project planning and feature prioritization.*
