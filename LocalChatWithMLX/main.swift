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

let modelConfiguration = LLMRegistry.llama3_2_1B_4bit

let model = try await #huggingFaceLoadModelContainer(
    configuration: modelConfiguration
)

let session = ChatSession(model)
print(try await session.respond(to: "What are two things to see in San Francisco?"))
print(try await session.respond(to: "How about a great place to eat?"))
