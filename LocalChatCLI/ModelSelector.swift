import Foundation
import LocalChatKit

struct ModelSelector {
    let manager: ModelManager

    func run() async -> LoadedModel {
        while true {
            let allModels = Model.allCases
            var statuses: [(model: Model, isDownloaded: Bool)] = []
            for model in allModels {
                statuses.append((model: model, isDownloaded: await manager.isDownloaded(model)))
            }

            TerminalOutput.printHeader()
            TerminalOutput.printModelList(statuses)

            guard let index = promptSelection(count: allModels.count) else {
                print("Please enter a number between 1 and \(allModels.count).\n")
                continue
            }
            let selected = allModels[index]

            if !statuses[index].isDownloaded {
                guard promptDownload(model: selected) else {
                    print("")
                    continue
                }
                guard await download(selected) else { continue }
            }

            if let loaded = await load(selected) {
                return loaded
            }
        }
    }

    // MARK: - Private

    private func promptSelection(count: Int) -> Int? {
        print("Select model [1-\(count)]: ", terminator: "")
        fflush(stdout)
        guard let line = readLine(),
              let n = Int(line.trimmingCharacters(in: .whitespacesAndNewlines)),
              n >= 1, n <= count else { return nil }
        return n - 1
    }

    private func promptDownload(model: Model) -> Bool {
        print("Model not downloaded. Download now? (\(model.sizeLabel)) [y/N]: ", terminator: "")
        fflush(stdout)
        let answer = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return answer == "y" || answer == "yes"
    }

    private func download(_ model: Model) async -> Bool {
        do {
            let stream = await manager.download(model)
            for try await progress in stream {
                print(TerminalOutput.formatDownloadProgress(progress), terminator: "")
                fflush(stdout)
            }
            print("")
            print("Download complete.\n")
            return true
        } catch {
            print("\n[Download failed: \(error.localizedDescription)]\n")
            return false
        }
    }

    private func load(_ model: Model) async -> LoadedModel? {
        do {
            var result: LoadedModel? = nil
            let stream = await manager.load(model)
            for try await progress in stream {
                switch progress {
                case .loading(let fraction):
                    let pct = Int(fraction * 100)
                    print("\(TerminalOutput.clearLine)Loading \(model.displayName)... \(pct)%", terminator: "")
                    fflush(stdout)
                case .ready(let loaded):
                    result = loaded
                }
            }
            print("")
            return result
        } catch {
            print("\n[Load failed: \(error.localizedDescription)]\n")
            return nil
        }
    }
}
