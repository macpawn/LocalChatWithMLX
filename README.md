# LocalChatWithMLX

A macOS app for chatting with LLMs running entirely on-device via [MLX](https://github.com/ml-explore/mlx-swift-lm). No internet connection required after model download.

## Requirements

- macOS 14+
- Apple Silicon (M1 or later)
- Xcode 15+

## Features

- Download and manage models from HuggingFace
- Streaming token output
- Multiple model support (Gemma 4, Llama 3.2)
- Conversation history with session reset

## Getting Started

1. Clone the repository
2. Open `LocalChatWithMLX.xcodeproj` in Xcode
3. Build and run (⌘R)
4. On first launch, download a model from the Model Library

> **First build note:** Xcode will ask permission to build Swift macros. Click **Trust & Enable**.

## Architecture

The app is built on top of **LocalChatKit** — a Swift Package that handles model management and inference.

→ [LocalChatKit README](LocalChatKit/README.md)

## License

MIT
