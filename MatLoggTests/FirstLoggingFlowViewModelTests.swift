import Testing
@testable import MatLogg

@MainActor
struct FirstLoggingFlowViewModelTests {
    @Test func introductionRequiresNextThenExplicitStart() {
        let model = FirstLoggingFlowViewModel()
        #expect(model.introPage == .logging)
        model.advanceIntroduction()
        #expect(model.introPage == .overview)
        #expect(model.step == .introduction)
        model.selectPage(.logging)
        #expect(model.step == .introduction)
        model.selectPage(.overview)
        model.advanceIntroduction()
        #expect(model.step == .logging)
    }

    @Test func eitherIntroductionPageCanBeSkipped() {
        for page in FirstLoggingFlowViewModel.IntroPage.allCases {
            let model = FirstLoggingFlowViewModel()
            model.selectPage(page)
            model.startLogging()
            #expect(model.step == .logging)
            #expect(FirstLoggingFlowViewModel().introPage == .logging)
        }
    }
}
