import Foundation
import Combine

@MainActor
final class MorningCheckInViewModel: ObservableObject {
    @Published var weightText = ""
    @Published var isPresented = false
    @Published private(set) var status: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    private let repository: any HealthProfileRepository
    private let store: any MorningCheckInStore
    private var userId: UUID?
    private var day = Date.distantPast
    private var entry: WeightEntry?
    private var requestID = UUID()

    init(repository: any HealthProfileRepository, store: any MorningCheckInStore) {
        self.repository = repository
        self.store = store
    }

    func load(userId: UUID?, date: Date) async {
        let newDay = Calendar.current.startOfDay(for: date)
        if isSaving, self.userId == userId, day == newDay { return }
        let request = UUID()
        requestID = request
        if self.userId != userId || day != newDay {
            isPresented = false
            weightText = ""
            errorMessage = nil
            entry = nil
        }
        self.userId = userId
        day = newDay
        status = userId.map { store.status(userId: $0, day: newDay) } ?? nil
        guard let userId else { isLoading = false; return }
        isLoading = true
        let entries = await repository.getWeightEntries(userId: userId)
        guard requestID == request else { return }
        entry = entries.last { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: newDay) }
        isLoading = false
    }

    func begin() {
        guard userId != nil, !isLoading, !isSaving else { return }
        weightText = entry.map { String($0.weightKg).replacingOccurrences(of: ".", with: ",") } ?? ""
        errorMessage = nil
        isPresented = true
    }

    func skip() {
        guard let userId, !isSaving else { return }
        store.setStatus("skipped", userId: userId, day: day)
        status = "skipped"
        isPresented = false
    }

    @discardableResult
    func finish() async -> Bool {
        guard let userId, !isSaving, !isLoading else { return false }
        let text = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = Double(text.replacingOccurrences(of: ",", with: "."))
        guard text.isEmpty || (weight.map { $0.isFinite && $0 > 0 && $0 <= 500 } ?? false) else {
            errorMessage = "Skriv en gyldig vekt i kg, større enn 0 og opptil 500, eller la feltet stå tomt."
            return false
        }
        let savingDay = day
        let request = requestID
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let weight, weight != entry?.weightKg {
                let updated = WeightEntry(id: entry?.id ?? UUID(), userId: userId, date: savingDay,
                                          weightKg: weight, createdAt: entry?.createdAt ?? Date())
                try await repository.saveWeightEntry(updated)
                if requestID == request { entry = updated }
            }
            store.setStatus("completed", userId: userId, day: savingDay)
            guard requestID == request else { return false }
            status = "completed"
            isPresented = false
            return true
        } catch {
            if requestID == request { errorMessage = "Kunne ikke lagre vekten. Prøv igjen." }
            return false
        }
    }
}
