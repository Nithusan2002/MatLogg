import Foundation
import Combine

@MainActor
final class PersonalDetailsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var weight = ""
    @Published var height = ""
    @Published var birthDate: Date?
    @Published var gender: GenderOption = .ikkeOppgi
    @Published var activity: ActivityLevel = .ikkeOppgi
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var errorMessage: String?

    private let store: any PersonalDetailsStore
    private let onSaved: (PersonalDetails) -> Void
    private var userId: UUID?

    init(store: any PersonalDetailsStore, onSaved: @escaping (PersonalDetails) -> Void = { _ in }) {
        self.store = store
        self.onSaved = onSaved
    }

    func begin(details: PersonalDetails, userId: UUID?) {
        self.userId = userId
        displayName = details.displayName ?? ""
        weight = details.weightKg.map { String($0).replacingOccurrences(of: ".", with: ",") } ?? ""
        height = details.heightCm.map { String($0).replacingOccurrences(of: ".", with: ",") } ?? ""
        birthDate = details.birthDate
        gender = details.gender ?? .ikkeOppgi
        activity = details.activityLevel ?? .ikkeOppgi
        errors = [:]
        errorMessage = nil
    }

    @discardableResult
    func save(now: Date = Date()) -> Bool {
        errors = [:]
        errorMessage = nil
        let weightKg = number(weight, field: "weight", unit: "kg")
        let heightCm = number(height, field: "height", unit: "cm")
        if let birthDate, birthDate > now {
            errors["birthDate"] = "Fødselsdato kan ikke være i fremtiden."
        }
        guard errors.isEmpty else { return false }
        guard let userId else {
            errorMessage = "Åpne skjermen på nytt når en profil er aktiv."
            return false
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = PersonalDetails(displayName: name.isEmpty ? nil : name, weightKg: weightKg, heightCm: heightCm,
                                      birthDate: birthDate,
                                      gender: gender == .ikkeOppgi ? nil : gender,
                                      activityLevel: activity == .ikkeOppgi ? nil : activity)
        do {
            try store.save(details, userId: userId)
            onSaved(details)
            return true
        } catch {
            errorMessage = "Kunne ikke lagre opplysningene. Endringene dine er beholdt. Prøv igjen."
            return false
        }
    }

    private func number(_ text: String, field: String, unit: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value > 0 else {
            errors[field] = "Skriv et gyldig tall over 0 \(unit), eller la feltet stå tomt."
            return nil
        }
        return value
    }
}
