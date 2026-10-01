import SwiftUI

struct PersonalDetailsView: View {
    @EnvironmentObject private var healthProfile: HealthProfileViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var viewModel: PersonalDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var initialized = false
    @State private var showActivitySheet = false
    @State private var showActivityHelp = false
    @State private var showBirthDate = false
    @State private var birthDateDraft = Date()
    @FocusState private var focusedField: String?

    var body: some View {
        Form {
            Section {
                TextField("Navn (valgfritt)", text: $viewModel.displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: "name")
                    .accessibilityIdentifier("personal-details-name")
            } header: {
                Text("Profil")
            }
            .listRowBackground(AppColors.surface)

            Section {
                if let date = viewModel.birthDate {
                    LabeledContent("Fødselsdato") {
                        Button(date.formatted(date: .abbreviated, time: .omitted)) {
                            birthDateDraft = date
                            showBirthDate = true
                        }
                    }
                    Button("Fjern fødselsdato") { viewModel.birthDate = nil }
                } else {
                    Button("Oppgi fødselsdato (valgfritt)") {
                        birthDateDraft = Date()
                        showBirthDate = true
                    }
                }
                fieldError("birthDate")
                Picker("Kjønn", selection: $viewModel.gender) {
                    ForEach(GenderOption.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                numberField("Høyde", unit: "cm", key: "height", text: $viewModel.height)
                numberField("Vekt", unit: "kg", key: "weight", text: $viewModel.weight)
                Button { showActivitySheet = true } label: {
                    LabeledContent("Aktivitetsnivå") {
                        HStack {
                            Text(viewModel.activity.label)
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                DisclosureGroup("Hvorfor spør vi?") {
                    Text("Fødselsdato, kjønn, høyde, vekt og aktivitetsnivå brukes til å beregne et veiledende forslag til kalorimål. Vekten legges ikke til i vekthistorikken. Velger du Annet eller Ønsker ikke å oppgi for kjønn, kan du sette målet selv.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } header: {
                Text("Grunnlag for målforslag")
            } footer: {
                Text("Du kan også sette mål selv uten å fylle inn disse opplysningene.")
            }
            .listRowBackground(AppColors.surface)

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(AppColors.ink)
                        .accessibilityIdentifier("personal-details-error")
                }
                .listRowBackground(AppColors.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.action)
        .navigationTitle("Personlige detaljer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Avbryt", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Går tilbake uten å lagre endringer")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lagre") {
                    focusedField = nil
                    if viewModel.save() { dismiss() }
                }
                .accessibilityIdentifier("personal-details-save")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { focusedField = nil }
            }
        }
        .onAppear {
            guard !initialized else { return }
            viewModel.begin(details: healthProfile.personalDetails, userId: auth.currentUser?.id)
            initialized = true
        }
        .sheet(isPresented: $showActivitySheet, onDismiss: {
            if showActivityHelp { showActivityHelp = false; showHelp = true }
        }) {
            ActivityLevelSheet(selected: $viewModel.activity, onShowHelp: { showActivityHelp = true })
        }
        .sheet(isPresented: $showHelp) { ActivityLevelHelpSheet() }
        .sheet(isPresented: $showBirthDate) {
            NavigationStack {
                Form {
                    DatePicker("Velg fødselsdato", selection: $birthDateDraft, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel)
                }
                .navigationTitle("Fødselsdato")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Avbryt") { showBirthDate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Bruk dato") {
                            viewModel.birthDate = birthDateDraft
                            showBirthDate = false
                        }
                    }
                }
            }
        }
    }

    @State private var showHelp = false

    private func numberField(_ title: String, unit: String, key: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(unit))").font(AppTypography.bodyEmphasis)
            TextField("Valgfritt", text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: key)
                .frame(minHeight: 44)
                .accessibilityLabel("\(title), \(unit)")
                .accessibilityIdentifier("personal-details-\(key)")
            fieldError(key)
        }
    }

    @ViewBuilder private func fieldError(_ key: String) -> some View {
        if let error = viewModel.errors[key] {
            Text(error).font(AppTypography.caption).foregroundStyle(AppColors.ink)
        }
    }
}

struct ActivityLevelSheet: View {
    @Binding var selected: ActivityLevel
    let onShowHelp: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let options: [ActivityLevel] = [.lav, .moderat, .hoy, .veldigHoy, .ikkeOppgi]
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                .foregroundColor(AppColors.action)
                
                Spacer()
            }
            .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .foregroundColor(AppColors.action)
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
                        Text("• Hvis du er “midt i mellom” → Moderat.")
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
                        .foregroundColor(AppColors.action)
                }
            }
        }
    }
}
