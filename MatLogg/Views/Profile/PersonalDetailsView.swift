import SwiftUI

struct PersonalDetailsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var gender: GenderOption = .ikkeOppgi
    @State private var activity: ActivityLevel = .ikkeOppgi
    
    var body: some View {
        Form {
            Section {
                Text("Alt er valgfritt. Målet er å gi deg bedre oversikt, ikke press.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Section("Om deg") {
                TextField("Nåværende vekt (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                TextField("Høyde (cm)", text: $heightText)
                    .keyboardType(.decimalPad)
                
                Toggle("Fødselsdato", isOn: $hasBirthDate)
                if hasBirthDate {
                    DatePicker("Velg dato", selection: $birthDate, displayedComponents: .date)
                }
                
                Picker("Kjønn", selection: $gender) {
                    ForEach(GenderOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                
                Picker("Aktivitetsnivå", selection: $activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
            }
        }
        .navigationTitle("Personlige detaljer")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Lagre") {
                    save()
                    dismiss()
                }
                .foregroundColor(AppColors.brand)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { hideKeyboard() }
                    .foregroundColor(AppColors.brand)
            }
        }
        .onAppear {
            load()
        }
    }
    
    private func load() {
        let details = appState.personalDetails
        if let weight = details.weightKg {
            weightText = formatNumber(weight)
        }
        if let height = details.heightCm {
            heightText = formatNumber(height)
        }
        if let date = details.birthDate {
            birthDate = date
            hasBirthDate = true
        }
        if let gender = details.gender {
            self.gender = gender
        }
        if let activity = details.activityLevel {
            self.activity = activity
        }
    }
    
    private func save() {
        appState.personalDetails = PersonalDetails(
            weightKg: parseNumber(weightText),
            heightCm: parseNumber(heightText),
            birthDate: hasBirthDate ? birthDate : nil,
            gender: gender == .ikkeOppgi ? nil : gender,
            activityLevel: activity == .ikkeOppgi ? nil : activity
        )
    }
    
    private func parseNumber(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
