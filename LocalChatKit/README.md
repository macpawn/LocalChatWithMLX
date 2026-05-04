# LocalChatKit

A Swift Package for running LLMs locally on Apple Silicon via [MLX](https://github.com/ml-explore/mlx-swift-lm). Download models from HuggingFace, run inference entirely offline, and stream tokens or receive complete responses.

## Requirements

- macOS 14+
- Apple Silicon (M1 or later)
- Swift 5.9+

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | ≥ 3.31.3 | LLM inference on Apple Silicon via MLX |
| [swift-huggingface](https://github.com/huggingface/swift-huggingface) | ≥ 0.9.0 | HuggingFace Hub API (model metadata, download) |
| [swift-transformers](https://github.com/huggingface/swift-transformers) | ≥ 1.3.0 | Tokenizers |

> **First build note:** Xcode will ask permission to build Swift macros (used internally by `mlx-swift-lm` / `swift-transformers`). Click **Trust & Enable** — macros are required for the package to compile.

Each direct dependency pulls in its own dependencies, so the full resolved graph is larger:

| Package | Version |
|---------|---------|
| EventSource | 1.4.1 |
| Jinja | 2.3.5 |
| mlx-swift | 0.31.3 |
| swift-asn1 | 1.7.0 |
| swift-atomics | 1.3.0 |
| swift-collections | 1.4.1 |
| swift-crypto | 4.4.0 |
| swift-nio | 2.98.0 |
| swift-numerics | 1.1.1 |
| swift-syntax | 600.0.1 |
| swift-system | 1.6.4 |
| yyjson | 0.12.0 |

## Installation

```swift
// Package.swift
.package(url: "<repo-url>", from: "1.0.0")

// Target dependencies
.product(name: "LocalChatKit", package: "LocalChatKit"),

// Test targets only
.product(name: "LocalChatKitMocks", package: "LocalChatKit"),
```

## Quick Start

```swift
import LocalChatKit

let manager = ModelManager()

// 1. Download the model (if not already on disk)
for try await progress in manager.download(.llama3_2_1B) {
    print("\(progress.percent)%")
}

// 2. Load the model into memory
let model = try await manager.loadModel(.llama3_2_1B)

// 3. Create a session and send a message
let session = ChatSession(model: model, systemPrompt: "You are a helpful assistant.")
let response = try await session.send("Hello!")
print(response.text)
```

## Available Models

| Model | Enum | Approx. size |
|-------|------|--------------|
| Gemma 4 4B (4-bit) | `.gemma4_e4b` | ~3 GB |
| Gemma 4 2B (4-bit) | `.gemma4_e2b` | ~1.5 GB |
| Llama 3.2 3B (4-bit) | `.llama3_2_3B` | ~2 GB |
| Llama 3.2 1B (4-bit) | `.llama3_2_1B` | ~0.8 GB |

All models are downloaded from [mlx-community](https://huggingface.co/mlx-community) on HuggingFace and cached locally at `~/.cache/huggingface/hub` (or `~/Library/Caches/huggingface/hub` in sandboxed apps).

## API Reference

### ModelManager

```swift
let manager = ModelManager()                                    // default cache location
let manager = ModelManager(storage: .init(baseDirectory: url)) // custom cache

await manager.isDownloaded(.llama3_2_1B)                       // fast size check
await manager.isDownloaded(.llama3_2_1B, check: .thorough)     // SHA-256 check
try await manager.delete(.llama3_2_1B)                         // remove from disk
for try await progress in manager.download(.llama3_2_1B) { }   // stream download
for try await progress in manager.load(.llama3_2_1B) { }       // stream load into RAM
try await manager.loadModel(.llama3_2_1B)                      // convenience → LoadedModel
```

`load()` returns `AsyncThrowingStream<LoadProgress, Error>` with two event types:
- `.loading(fraction: Double)` — weight loading progress (0.0–1.0)
- `.ready(LoadedModel)` — model is ready for inference

### ChatSession

```swift
let session = ChatSession(model: model)
let session = ChatSession(model: model, systemPrompt: "You are concise.")

// Streaming tokens
for try await event in session.sendStreaming("What is 2+2?") {
    switch event {
    case .token(let text):       print(text, terminator: "")
    case .completed(let stats):  print("\n\(stats.tokensPerSecond) tok/s")
    }
}

// Full response
let response = try await session.send("Summarize quantum computing.")
print(response.text)
print(response.stats.tokensPerSecond)

// History and reset
let history = await session.history    // [ChatMessage]
await session.clearHistory()           // resets the KV cache and message history
```

### GenerationOptions

```swift
let opts = GenerationOptions(temperature: 0.7, topP: 0.9, maxTokens: nil)
for try await event in await session.sendStreaming("Hello", sampling: opts) {
    // handle streamed tokens
}
```

`maxTokens` is optional. Pass `nil` to leave response length uncapped by LocalChatKit.

### GenerationStats

```swift
response.stats.timeToFirstToken    // TimeInterval
response.stats.tokensPerSecond     // Double
response.stats.promptTokenCount    // Int
response.stats.generatedTokenCount // Int
response.stats.totalDuration       // TimeInterval
```

## Testing with Mocks

Add `LocalChatKitMocks` to your test target. It provides `MockChatSession` and `MockModelManager`, both conforming to their respective protocols.

```swift
import LocalChatKit
import LocalChatKitMocks

// MockChatSession
let session = MockChatSession()
await session.stub(events: [
    .token("Hello"),
    .token(" world"),
    .completed(GenerationStats(timeToFirstToken: 0.1, tokensPerSecond: 50,
                               promptTokenCount: 5, generatedTokenCount: 2,
                               totalDuration: 0.2))
])
let response = try await session.send("Hi", options: .default)
// response.text == "Hello world"
// await session.sendCallCount == 1
// await session.lastMessage == "Hi"

// MockModelManager
let manager = MockModelManager()
await manager.seed(downloaded: [.llama3_2_1B])
// await manager.isDownloaded(.llama3_2_1B) == true

await manager.stub(downloadEvents: [
    DownloadProgress(percent: 50, bytesDownloaded: 512, totalBytes: 1024, bytesPerSecond: 100),
    DownloadProgress(percent: 100, bytesDownloaded: 1024, totalBytes: 1024, bytesPerSecond: 200),
])
```

> **Mock limitation:** `MockModelManager.load()` cannot emit `.ready(LoadedModel)` because `ModelContainer` from MLX has no public initializer. Tests that need to verify post-load logic should use `MockChatSession` directly, which bypasses model loading entirely.

## Dependency Injection with Protocols

Both core types expose protocols — use them in ViewModels and services to keep production code testable.

```swift
final class ChatViewModel: ObservableObject {
    let session: any ChatSessionProtocol

    init(session: any ChatSessionProtocol) {
        self.session = session
    }
}

// Production
let vm = ChatViewModel(session: ChatSession(model: loadedModel))

// Tests
let vm = ChatViewModel(session: MockChatSession())
```

## Nuances

### Model cache location
Models are stored in HubCache format: `~/.cache/huggingface/hub/models--{org}--{repo}/`. In sandboxed apps the path is `~/Library/Caches/huggingface/hub/`. Pass a custom `ModelStorageConfig(baseDirectory:)` to override.

### Cancellation
`sendStreaming` correctly cancels the underlying generation task when the caller breaks out of the loop or cancels the parent `Task`. The inner `Task` is stopped via `withTaskCancellationHandler` + `continuation.onTermination`. **Important:** cancellation does not append a partial exchange to `history`. Call `clearHistory()` after a cancelled turn if you want to reset the session to a clean state.

### Concurrency
`ChatSession` and `ModelManager` are Swift actors. Concurrent calls to `sendStreaming` on the same session are queued, not parallelised. Loading multiple models via separate `ModelManager` instances simultaneously is safe.

### Memory
A loaded model occupies RAM for its entire lifetime. Release it by letting the `LoadedModel` go out of scope. The `ChatSession` KV cache grows with conversation length; `clearHistory()` resets it.

### Sandbox detection
The library auto-detects sandboxing via `APP_SANDBOX_CONTAINER_ID` and selects the correct cache directory automatically.
