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

/// An actor that owns the non-Sendable ChatSession and performs all interactions off the main actor.
actor ChatWorker {
    private let session: ChatSession

    init(modelConfiguration: ModelConfiguration) async throws {
        let container = try await #huggingFaceLoadModelContainer(
            configuration: modelConfiguration
        )
        self.session = ChatSession(container)
    }

    func ask(_ prompt: String) async throws {
        print("\nUser: \(prompt)")
        print("Assistant: ", terminator: "")
        for try await chunk in session.streamResponse(to: prompt, images: [], videos: []) {
            print(chunk, terminator: "")
            fflush(stdout)
        }
        print()
    }

    func askWithDetails(_ prompt: String) async throws {
        print("\nUser: \(prompt)")
        print("Assistant: ", terminator: "")
        var stats: GenerateCompletionInfo? = nil
        for try await generation in session.streamDetails(to: prompt, images: [], videos: []) {
            if case .chunk(let text) = generation {
                print(text, terminator: "")
                fflush(stdout)
            }
            if case .info(let info) = generation {
                stats = info
            }
        }

        print()
        if let stats {
            print(stats)
        }
        print()
    }
}

// Run everything off the main actor.
let worker = try await ChatWorker(modelConfiguration: modelConfiguration)

try await worker.askWithDetails("What are two things to see in San Francisco?")
