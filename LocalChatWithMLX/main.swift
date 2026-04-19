//
//  main.swift
//  LocalChatWithMLX
//
//  Created by Dmytro on 19.04.2026.
//

import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

let modelConfiguration = LLMRegistry.gemma4_e2b_it_4bit

struct WorkerResult {
    let id: Int
    let prompt: String
    let response: String
    let stats: GenerateCompletionInfo?
}

/// An actor that owns a single ChatSession and performs all interactions off the main actor.
actor ChatWorker {
    let id: Int
    private let session: ChatSession

    init(id: Int, container: ModelContainer) {
        self.id = id
        self.session = ChatSession(container)
    }

    func askWithDetails(_ prompt: String) async throws -> WorkerResult {
        var buffer = ""
        var stats: GenerateCompletionInfo? = nil
        for try await generation in session.streamDetails(to: prompt, images: [], videos: []) {
            if case .chunk(let text) = generation {
                buffer += text
            }
            if case .info(let info) = generation {
                stats = info
            }
        }
        return WorkerResult(id: id, prompt: prompt, response: buffer, stats: stats)
    }
}

// Load the container once, shared by all sessions.
print("Loading model...")
let sharedContainer = try await #huggingFaceLoadModelContainer(
    configuration: modelConfiguration
)
print("Model loaded. Starting parallel sessions...\n")

let worker1 = ChatWorker(id: 1, container: sharedContainer)
let worker2 = ChatWorker(id: 2, container: sharedContainer)
let worker3 = ChatWorker(id: 3, container: sharedContainer)

// Run all three sessions in parallel, collect results.
let results = try await withThrowingTaskGroup(of: WorkerResult.self) { group in
    group.addTask { try await worker1.askWithDetails("What are two things to see in San Francisco?") }
    group.addTask { try await worker2.askWithDetails("Name two famous dishes from Italy.") }
    group.addTask { try await worker3.askWithDetails("What is the capital of Japan?") }
    return try await group.reduce(into: [WorkerResult]()) { $0.append($1) }
}

// Print results sorted by worker id.
for result in results.sorted(by: { $0.id < $1.id }) {
    print("=== Worker \(result.id) ===")
    print("User: \(result.prompt)")
    print("Assistant: \(result.response)")
    if let stats = result.stats {
        let tps = Double(stats.generationTokenCount) / stats.generateTime
        print(String(format: "Stats: %d tokens, %.1f tok/s", stats.generationTokenCount, tps))
    }
    print()
}

print("All sessions completed.")
