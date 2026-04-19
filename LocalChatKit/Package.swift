// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalChatKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LocalChatKit", targets: ["LocalChatKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", .upToNextMinor(from: "0.9.0")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.3.0")),
    ],
    targets: [
        .target(
            name: "LocalChatKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]
        ),
        .testTarget(
            name: "LocalChatKitTests",
            dependencies: ["LocalChatKit"]
        ),
    ]
)
