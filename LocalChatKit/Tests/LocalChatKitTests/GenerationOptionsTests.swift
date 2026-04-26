import Testing
@testable import LocalChatKit

struct GenerationOptionsTests {

    @Test func defaultOptionsHaveNilFields() {
        let opts = GenerationOptions.default
        #expect(opts.temperature == nil)
        #expect(opts.maxTokens == nil)
    }

    @Test func customOptionsPreserveValues() {
        let opts = GenerationOptions(temperature: 0.7, maxTokens: 512)
        #expect(opts.temperature == 0.7)
        #expect(opts.maxTokens == 512)
    }

    @Test func partialOptionsAreAllowed() {
        let opts = GenerationOptions(temperature: 0.5)
        #expect(opts.temperature == 0.5)
        #expect(opts.maxTokens == nil)
    }

    @Test func loadProgressLoadingCaseHoldsFraction() {
        let p = LoadProgress.loading(fraction: 0.5)
        if case .loading(let fraction) = p {
            #expect(fraction == 0.5)
        } else {
            Issue.record("Expected .loading case")
        }
    }

    @Test func loadProgressReadyCaseExistsAtCompileTime() {
        // LoadedModel cannot be instantiated without MLX in unit tests.
        // Verified via compiler: LoadProgress.ready(_:) accepts LoadedModel.
        // This test confirms the enum cases compile and pattern-match correctly.
        let p = LoadProgress.loading(fraction: 1.0)
        if case .ready = p {
            Issue.record("Should not be .ready")
        }
    }
}
