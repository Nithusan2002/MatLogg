import Foundation
import Combine

@MainActor
final class HealthHistoryExportViewModel: ObservableObject {
    enum Period: String, CaseIterable { case week = "Siste 7 dager", month = "Siste 30 dager", custom = "Velg periode" }
    @Published var period: Period = .month { didSet { invalidatePreview() } }
    @Published var startDate = Date() { didSet { invalidatePreview() } }
    @Published var endDate = Date() { didSet { invalidatePreview() } }
    @Published var nutrition = false { didSet { invalidatePreview() } }
    @Published var weight = false { didSet { invalidatePreview() } }
    @Published private(set) var settings = HealthIntegrationSettings()
    @Published private(set) var preview: HealthHistoryPreview?
    @Published private(set) var result: HealthHistoryResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    private var owner: UUID?
    private var context = UUID()
    private let repository: any HealthIntegrationRepository
    private let calendar: Calendar
    private let now: () -> Date

    init(repository: any HealthIntegrationRepository, owner: UUID?, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.owner = owner
        self.calendar = calendar
        self.now = now
        let today = now()
        startDate = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        endDate = today
    }
    func endDateForPreview(_ preview: HealthHistoryPreview) -> Date {
        calendar.date(byAdding: .day, value: -1, to: preview.request.end) ?? preview.request.start
    }
    var validationMessage: String? {
        if !settings.isConnected { return "Aktiver deling fra Apple Helse-innstillingene først." }
        if period == .custom && calendar.startOfDay(for: startDate) > calendar.startOfDay(for: endDate) {
            return "Fra-datoen må være før eller lik til-datoen."
        }
        if !nutrition && !weight { return "Velg minst én datagruppe." }
        return nil
    }
    var canPreview: Bool { repository.isAvailable && !isBusy && request != nil }
    private var request: HealthHistoryRequest? {
        let today = calendar.startOfDay(for: now())
        let last = period == .custom ? calendar.startOfDay(for: endDate) : today
        let first: Date
        switch period {
        case .week: first = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month: first = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .custom: first = calendar.startOfDay(for: startDate)
        }
        guard last <= today, let end = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        let request = HealthHistoryRequest(start: first, end: end,
            nutrition: nutrition && settings.shareNutrition, weight: weight && settings.shareWeight)
        return request.isValid ? request : nil
    }
    private func invalidatePreview() { preview = nil; result = nil; errorMessage = nil }
    func selectOwner(_ owner: UUID?) {
        guard self.owner != owner else { return }
        context = UUID()
        self.owner = owner
        settings = HealthIntegrationSettings()
        nutrition = false
        weight = false
        isBusy = false
        invalidatePreview()
    }
    func load() async {
        guard let owner, !isBusy else { return }
        let token = context
        isBusy = true
        defer { if token == context { isBusy = false } }
        do {
            let status = try await repository.status(owner: owner)
            guard token == context else { return }
            settings = status.settings
            nutrition = settings.isConnected && settings.shareNutrition
            weight = settings.isConnected && settings.shareWeight
        } catch {
            guard token == context else { return }
            errorMessage = "Kunne ikke lese delingsvalgene. Prøv igjen."
        }
    }
    func prepare() async {
        guard let owner, canPreview, let request else { return }
        let token = context
        isBusy = true
        invalidatePreview()
        defer { if token == context { isBusy = false } }
        do {
            let value = try await repository.previewHistory(owner: owner, request: request)
            guard token == context, self.request == request else { return }
            preview = value
        } catch { if token == context { errorMessage = "Kunne ikke lese historikken. Kontroller perioden og aktive delingsvalg." } }
    }
    func share() async {
        guard let owner, let preview, !isBusy, request == preview.request else { return }
        let token = context
        isBusy = true
        errorMessage = nil
        defer { if token == context { isBusy = false } }
        do {
            let value = try await repository.shareHistory(owner: owner, preview: preview)
            guard token == context else { return }
            result = value
            self.preview = nil
        } catch HealthIntegrationError.historyChanged {
            guard token == context else { return }
            self.preview = nil
            errorMessage = "Historikken er endret. Vis oversikten på nytt før du deler."
        } catch {
            guard token == context else { return }
            self.preview = nil
            errorMessage = "Overføringen kunne ikke fullføres. Eventuelle kølagte verdier er bevart. Kontroller delingsvalgene og prøv igjen."
        }
    }
}
