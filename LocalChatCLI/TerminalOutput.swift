import Foundation
import LocalChatKit

enum TerminalOutput {
    // It works in terminal. it doesn't work properly in Xcode terminal
    static let clearLine = "\u{1B}[2K\r"
    private static let bold  = "\u{1B}[1m"
    private static let dim   = "\u{1B}[2m"
    private static let reset = "\u{1B}[0m"

    static func progressBar(fraction: Double, width: Int = 20) -> String {
        let clamped = max(0.0, min(1.0, fraction))
        let filled = Int(clamped * Double(width))
        let empty = width - filled
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "]"
    }

    static func formatStats(_ stats: GenerationStats) -> String {
        let ttft = String(format: "%.1f", stats.timeToFirstToken)
        let tps  = String(format: "%.1f", stats.tokensPerSecond)
        return "\(dim)[tokens: \(stats.promptTokenCount) prompt + \(stats.generatedTokenCount) generated · \(tps) tok/s · TTFT \(ttft)s]\(reset)"
    }

    static func formatDownloadProgress(_ progress: DownloadProgress) -> String {
        let bar     = progressBar(fraction: Double(progress.percent) / 100.0)
        let dlGB    = String(format: "%.1f", Double(progress.bytesDownloaded) / 1_073_741_824)
        let totalGB = String(format: "%.1f", Double(progress.totalBytes)      / 1_073_741_824)
        let speedMB = String(format: "%.1f", progress.bytesPerSecond          / 1_048_576)
        return "\(clearLine)Downloading... \(progress.percent)% \(bar) \(dlGB)/\(totalGB) GB · \(speedMB) MB/s"
    }

    static func printHeader() {
        print("\(bold)LocalChat CLI\(reset)")
        print("=============\n")
    }

    static func printModelList(_ entries: [(model: Model, isDownloaded: Bool)]) {
        print("Available models:")
        for (i, entry) in entries.enumerated() {
            let name   = entry.model.displayName.padding(toLength: 16, withPad: " ", startingAt: 0)
            let size   = entry.model.sizeLabel.padding(toLength: 7,  withPad: " ", startingAt: 0)
            let status = entry.isDownloaded ? "✓ ready" : "⬇ not downloaded"
            print("  [\(i + 1)] \(name) \(size) \(status)")
        }
        print("")
    }
}
