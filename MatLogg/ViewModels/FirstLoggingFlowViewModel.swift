import Combine

@MainActor
final class FirstLoggingFlowViewModel: ObservableObject {
    enum Step { case introduction, logging }
    @Published private(set) var step: Step = .introduction

    enum IntroPage: Int, CaseIterable {
        case logging, overview

        var title: String {
            switch self {
            case .logging: return "Matlogging gjort enkelt"
            case .overview: return "Oversikt på dine premisser"
            }
        }

        var message: String {
            switch self {
            case .logging: return "Søk etter mat eller skann strekkoden. Velg mengde og lagre."
            case .overview: return "Se hva du har spist. Sett egne mål hvis du ønsker."
            }
        }
    }

    @Published private(set) var introPage: IntroPage = .logging

    func selectPage(_ page: IntroPage) { introPage = page }

    func advanceIntroduction() {
        if introPage == .logging { introPage = .overview }
        else { startLogging() }
    }

    func startLogging() {
        step = .logging
    }
}
