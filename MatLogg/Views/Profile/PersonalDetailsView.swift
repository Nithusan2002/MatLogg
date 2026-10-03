import SwiftUI

struct PersonalDetailsView: View {
    @EnvironmentObject private var healthProfile: HealthProfileViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var viewModel: PersonalDetailsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var initialized = false
    @State private var showActivitySheet = false
    @State private var showActivityHelp = false
    @State private var showMeasurement: PersonalMeasurement?
    @State private var showBirthDate = false
    @State private var birthDateDraft = Date()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Fødselsdato må fylles inn. De øvrige opplysningene er valgfrie.")
                    .font(AppTypography.secondary)
                    .foregroundStyle(AppColors.textSecondary)

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Profil")
                    CardContainer {
                        detailRow("Navn") {
                            TextField("Valgfritt", text: $viewModel.displayName)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                                .focused($focusedField, equals: "name")
                                .accessibilityLabel("Navn, valgfritt")
                                .accessibilityIdentifier("personal-details-name")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionTitle("Grunnlag for målforslag")
                        Text("Brukes til et veiledende forslag til kalorimål.")
                            .font(AppTypography.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    CardContainer {
                        VStack(spacing: 0) {
                            Button {
                                focusedField = nil
                                birthDateDraft = viewModel.birthDate ?? Date()
                                showBirthDate = true
                            } label: {
                                detailRow("Fødselsdato") {
                                    selectionValue(viewModel.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "Ikke oppgitt")
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("personal-details-birth-date")
                            fieldError("birthDate")
                            Divider().overlay(AppColors.separator)
                            Menu {
                                Picker("Kjønn", selection: $viewModel.gender) {
                                    ForEach(GenderOption.allCases, id: \.self) { Text($0.label).tag($0) }
                                }
                            } label: {
                                detailRow("Kjønn") {
                                    selectionValue(viewModel.gender.label)
                                }
                            }
                            .accessibilityIdentifier("personal-details-gender")
                            Divider().overlay(AppColors.separator)
                            measurementRow(.height, text: $viewModel.height)
                            Divider().overlay(AppColors.separator)
                            measurementRow(.weight, text: $viewModel.weight)
                            Divider().overlay(AppColors.separator)
                            Button {
                                focusedField = nil
                                showActivitySheet = true
                            } label: {
                                detailRow("Aktivitetsnivå") {
                                    selectionValue(viewModel.activity.label)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Vekten her brukes bare som grunnlag for målforslag. Registrer vekt i Oversikt for å legge den til i vekthistorikken.")
                        .font(AppTypography.secondary)
                        .foregroundStyle(AppColors.textSecondary)
                }

                DisclosureGroup {
                    Text("Du kan sette mål selv uten et automatisk målforslag. Fødselsdato, kjønn, høyde, vekt og aktivitetsnivå brukes bare som grunnlag for et veiledende målforslag. Velger du Annet eller Ønsker ikke å oppgi for kjønn, kan du sette målet selv. Eksisterende mål endres ikke automatisk når du lagrer.")
                        .font(AppTypography.secondary)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 8)
                } label: {
                    Label("Om opplysningene og målforslag", systemImage: "info.circle")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(AppColors.ink)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.ink)
                        .accessibilityIdentifier("personal-details-error")
                }
            }
            .padding(16)
        }
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
        .sheet(item: $showMeasurement) { measurement in
            MeasurementPickerSheet(
                measurement: measurement,
                initialText: measurement == .weight ? viewModel.weight : viewModel.height
            ) { value in
                if measurement == .weight { viewModel.weight = value }
                else { viewModel.height = value }
            }
        }
        .sheet(isPresented: $showBirthDate) {
            NavigationStack {
                ScrollView {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Velg fødselsdato")
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(AppColors.ink)
                            DatePicker("Fødselsdato", selection: $birthDateDraft, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "nb_NO"))
                                .accessibilityIdentifier("personal-details-birth-date-picker")
                        }
                    }
                    .padding(16)
                }
                .background(AppColors.background.ignoresSafeArea())
                .tint(AppColors.action)
                .toolbarBackground(AppColors.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
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
            .presentationBackground(AppColors.background)
        }
    }

    @State private var showHelp = false

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.sectionTitle)
            .foregroundStyle(AppColors.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func detailRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(AppTypography.bodyEmphasis)
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 16) {
                    Text(title).font(AppTypography.bodyEmphasis)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    content()
                }
            }
        }
        .foregroundStyle(AppColors.ink)
        .frame(minHeight: 52)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func selectionValue(_ value: String) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            Image(systemName: "chevron.right")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)
        }
    }

    private func measurementRow(_ measurement: PersonalMeasurement, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                focusedField = nil
                showMeasurement = measurement
            } label: {
                detailRow(measurement == .weight ? "Vekt brukt i målforslag" : measurement.title) {
                    selectionValue(text.wrappedValue.isEmpty
                                   ? "Ikke oppgitt"
                                   : text.wrappedValue + " " + measurement.unit)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("personal-details-\(measurement.rawValue)")
            fieldError(measurement.rawValue)
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
