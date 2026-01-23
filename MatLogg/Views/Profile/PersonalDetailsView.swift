import SwiftUI

struct PersonalDetailsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var birthDate = Date()
    @State private var gender: GenderOption = .ikkeOppgi
    @State private var activity: ActivityLevel = .ikkeOppgi
    @State private var showActivitySheet = false
    @State private var showActivityHelp = false
    
    var body: some View {
        Form {
            Section {
                Text("Alt er valgfritt. Målet er å gi deg bedre oversikt, ikke press.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Section("Om deg") {
                HStack {
                    Text("Nåværende vekt")
                    Spacer()
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                        .foregroundColor(AppColors.textSecondary)
                }
                
                HStack {
                    Text("Høyde")
                    Spacer()
                    TextField("0", text: $heightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("cm")
                        .foregroundColor(AppColors.textSecondary)
                }
                
                DatePicker("Fødselsdato", selection: $birthDate, displayedComponents: .date)
                
                Picker("Kjønn", selection: $gender) {
                    ForEach(GenderOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                
                Button(action: { showActivitySheet = true }) {
                    HStack {
                        Text("Aktivitetsnivå")
                        Spacer()
                        Text(activity.label)
                            .foregroundColor(AppColors.textSecondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.textSecondary)
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
        .sheet(isPresented: $showActivitySheet) {
            ActivityLevelSheet(
                selected: $activity,
                onShowHelp: { showActivityHelp = true }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showActivityHelp) {
            ActivityLevelHelpSheet()
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
            birthDate: birthDate,
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

struct ActivityLevelSheet: View {
    @Binding var selected: ActivityLevel
    let onShowHelp: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let options: [ActivityLevel] = [.lav, .moderat, .hoy, .veldigHoy, .ikkeOppgi]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aktivitetsnivå")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    Text("Velg det som beskriver en vanlig uke.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selected = option
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(option.label)
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.ink)
                                    Spacer()
                                    if selected == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.brand)
                                    }
                                }
                                Text(option.description)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(12)
                            .background(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.separator, lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppColors.textSecondary)
                    Text("Tips: Velg nivå for en vanlig uke. Du kan alltid justere senere.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Button("Hjelp meg å velge") {
                    dismiss()
                    onShowHelp()
                }
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.brand)
                
                Spacer()
            }
            .padding(16)
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .foregroundColor(AppColors.brand)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct ActivityLevelHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hva mener vi med aktivitetsnivå?")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    
                    Text("Dette beskriver hvor mye du beveger deg i hverdagen (jobb/skole/transport) i en vanlig uke. Treningsøkter kommer i tillegg.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Slik velger du raskt")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                        Text("• Lavt: sitter mesteparten av dagen, lite gåing.")
                        Text("• Moderat: går litt hver dag, står/går en del, men ikke tungt arbeid.")
                        Text("• Høyt: mye gåing gjennom dagen, aktiv jobb eller veldig aktiv hverdag.")
                        Text("• Veldig høyt: fysisk krevende jobb eller svært høy hverdagsbelastning.")
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tommelfingerregel")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                        Text("• Hvis du ofte blir litt sliten bare av hverdagen → Høyt eller Veldig høyt.")
                        Text("• Hvis hverdagen er ganske rolig og mest stillesitting → Lavt.")
                        Text("• Hvis du er “midt i mellom” → Moderat (trygg standard).")
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    
                    Text("Tips: Du kan endre dette senere hvis det ikke føles riktig.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Hjelp")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .foregroundColor(AppColors.brand)
                }
            }
        }
    }
}
