//
//  main.swift
//  LocalChatWithMLX
//
//  Created by Dmytro on 19.04.2026.
//

import Foundation
import LocalChatKit

let manager = ModelManager()

// Download if needed
if await !manager.isDownloaded(.gemma4_e2b) {
    print("Downloading model...")
    for try await progress in manager.download(.gemma4_e2b) {
        print("\(progress.percent)% — \(String(format: "%.1f", progress.bytesPerSecond / 1024)) KB/s")
    }
}

// Load model
print("Loading model into memory...")
let model = try await manager.load(.gemma4_e2b)
print("Model ready.\n")

// Stateful session
let session = ChatSession(model: model, systemPrompt: "You are a helpful assistant.")

// Streaming
print("User: What are two things to see in San Francisco?")
print("Assistant: ", terminator: "")
for try await event in session.sendStreaming("What are two things to see in San Francisco?") {
    if case .token(let text) = event { print(text, terminator: ""); fflush(stdout) }
    if case .completed(let stats) = event {
        print("\n\n[\(String(format: "%.1f", stats.tokensPerSecond)) tok/s, TTFT: \(String(format: "%.2f", stats.timeToFirstToken))s]")
    }
}

// Non-streaming
print("\nUser: Give me a one-line summary.")
let response = try await session.send("Give me a one-line summary.")
print("Assistant: \(response.text)")
print("[\(String(format: "%.1f", response.stats.tokensPerSecond)) tok/s]")
