import Foundation
import Testing
@testable import LocalChatKit

struct ModelTests {

    @Test func huggingFaceIDsAreCorrect() {
        #expect(Model.smolLM135M.huggingFaceID == "mlx-community/SmolLM-135M-Instruct-4bit")
        #expect(Model.gemma4_e4b.huggingFaceID == "mlx-community/gemma-4-e4b-it-4bit")
        #expect(Model.gemma4_e2b.huggingFaceID == "mlx-community/gemma-4-e2b-it-4bit")
        #expect(Model.llama3_2_1B.huggingFaceID == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(Model.llama3_2_3B.huggingFaceID == "mlx-community/Llama-3.2-3B-Instruct-4bit")
    }

    @Test func allCasesCoversAllModels() {
        #expect(Model.allCases.count == 5)
    }

    @Test func defaultStorageConfigHasValidPath() {
        let config = ModelStorageConfig.default
        #expect(!config.baseDirectory.path.isEmpty)
    }

    @Test func customStorageConfigPreservesPath() {
        let url = URL(fileURLWithPath: "/tmp/models")
        let config = ModelStorageConfig(baseDirectory: url)
        #expect(config.baseDirectory == url)
    }
}
