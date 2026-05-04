import Testing
@testable import LocalChatKit

struct LoadProgressTests {

    @Test func loadProgressLoadingCaseHoldsFraction() {
        let p = LoadProgress.loading(fraction: 0.5)
        if case .loading(let fraction) = p {
            #expect(fraction == 0.5)
        } else {
            Issue.record("Expected .loading case")
        }
    }

    @Test func loadProgressReadyCaseExistsAtCompileTime() {
        let p = LoadProgress.loading(fraction: 1.0)
        if case .ready = p {
            Issue.record("Should not be .ready")
        }
    }
}
