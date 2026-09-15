import Foundation
import Combine

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var hapticsFeedbackEnabled: Bool { didSet { store(hapticsFeedbackEnabled, key: "hapticsFeedbackEnabled") } }
    @Published var soundFeedbackEnabled: Bool { didSet { store(soundFeedbackEnabled, key: "soundFeedbackEnabled") } }
    @Published var showGoalStatusOnHome: Bool { didSet { store(showGoalStatusOnHome, key: "showGoalStatusOnHome") } }
    @Published var safeModeEnabled: Bool {
        didSet {
            store(safeModeEnabled, key: "safeModeEnabled")
            if safeModeEnabled {
                safeModeHideCalories = true
                safeModeHideGoals = true
            }
        }
    }
    @Published var safeModeHideCalories: Bool { didSet { store(safeModeHideCalories, key: "safeModeHideCalories") } }
    @Published var safeModeHideGoals: Bool { didSet { store(safeModeHideGoals, key: "safeModeHideGoals") } }
    @Published var showNutritionSource: Bool { didSet { store(showNutritionSource, key: "showNutritionSource") } }
    @Published var analyticsEnabled: Bool {
        didSet {
            store(analyticsEnabled, key: "analyticsEnabled")
            AnalyticsManager.shared.setEnabled(analyticsEnabled)
        }
    }
    @Published var crashReportsEnabled: Bool {
        didSet {
            store(crashReportsEnabled, key: "crashReportsEnabled")
            CrashReportingManager.shared.setEnabled(crashReportsEnabled)
        }
    }
    @Published var hasSeenPrivacyChoices: Bool { didSet { store(hasSeenPrivacyChoices, key: "hasSeenPrivacyChoices") } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsFeedbackEnabled = defaults.object(forKey: "hapticsFeedbackEnabled") as? Bool ?? true
        soundFeedbackEnabled = defaults.object(forKey: "soundFeedbackEnabled") as? Bool ?? true
        showGoalStatusOnHome = defaults.object(forKey: "showGoalStatusOnHome") as? Bool ?? true
        safeModeEnabled = defaults.object(forKey: "safeModeEnabled") as? Bool ?? false
        safeModeHideCalories = defaults.object(forKey: "safeModeHideCalories") as? Bool ?? false
        safeModeHideGoals = defaults.object(forKey: "safeModeHideGoals") as? Bool ?? false
        showNutritionSource = defaults.object(forKey: "showNutritionSource") as? Bool ?? true
        analyticsEnabled = defaults.object(forKey: "analyticsEnabled") as? Bool ?? false
        crashReportsEnabled = defaults.object(forKey: "crashReportsEnabled") as? Bool ?? false
        hasSeenPrivacyChoices = defaults.object(forKey: "hasSeenPrivacyChoices") as? Bool ?? false
        AnalyticsManager.shared.setEnabled(analyticsEnabled)
        CrashReportingManager.shared.setEnabled(crashReportsEnabled)
    }

    func lastUsedAmount(for productId: UUID, userId: UUID?) -> Double? {
        let value = defaults.double(forKey: lastAmountKey(productId: productId, userId: userId))
        return value > 0 ? value : nil
    }

    func setLastUsedAmount(_ amount: Double, for productId: UUID, userId: UUID?) {
        defaults.set(amount, forKey: lastAmountKey(productId: productId, userId: userId))
    }

    func shouldUseLastAmount(for productId: UUID, userId: UUID?) -> Bool {
        defaults.bool(forKey: useLastAmountKey(productId: productId, userId: userId))
    }

    func setUseLastAmount(_ enabled: Bool, for productId: UUID, userId: UUID?) {
        defaults.set(enabled, forKey: useLastAmountKey(productId: productId, userId: userId))
    }

    private func store(_ value: Bool, key: String) {
        defaults.set(value, forKey: key)
    }

    private func lastAmountKey(productId: UUID, userId: UUID?) -> String {
        "lastAmount.\(userId?.uuidString ?? "anonymous").\(productId.uuidString)"
    }

    private func useLastAmountKey(productId: UUID, userId: UUID?) -> String {
        "useLastAmount.\(userId?.uuidString ?? "anonymous").\(productId.uuidString)"
    }
}
