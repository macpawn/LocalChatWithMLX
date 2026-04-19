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

let modelConfiguration = LLMRegistry.llama3_2_3B_4bit

let modelContainer = try await #huggingFaceLoadModelContainer(
    configuration: modelConfiguration
)

let session = ChatSession(modelContainer)

func ask(_ prompt: String) async throws {
    print("\nUser: \(prompt)")
    print("Assistant: ", terminator: "")
    for try await chunk in await session.streamResponse(to: prompt, images: [], videos: []) {
        print(chunk, terminator: "")
        fflush(stdout)
    }
    print()
}

func askWithDetails(_ prompt: String) async throws {
    print("\nUser: \(prompt)")
    print("Assistant: ", terminator: "")
    var stats: GenerateCompletionInfo? = nil
    for try await generation in await session.streamDetails(to: prompt, images: [], videos: []) {
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


try await askWithDetails("What are two things to see in San Francisco?")
try await askWithDetails("How about a great place to eat?")
try await askWithDetails("Yes")
