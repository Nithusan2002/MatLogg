import SwiftUI

struct CloudLogView: View {
    @EnvironmentObject private var model: CloudLogViewModel
    var body: some View {
        let confirmation = model.confirmation
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Utviklingstest", systemImage: "hammer")
                        .font(AppTypography.captionEmphasis)
                    Text("Matlogger i skyen").font(AppTypography.title)
                    Text("Kun matlogger og tilhørende matvareinformasjon inngår. Vann, vekt, mål, favoritter, måltider og bilder er ikke med.")
                    Text("Lagring skjer først på denne iPhonen. Når du aktiverer synk, overføres matlogger i det lokale testmiljøet. Dette er ikke en full sikkerhetskopi.")
                        .foregroundStyle(AppColors.textSecondary)
                }.padding(20).matLoggCardSurface()

                if model.isAvailable {
                    VStack(alignment: .leading, spacing: 12) {
                        if !model.isEnabled {
                        Text("Aktiver matloggsynk").font(AppTypography.bodyEmphasis)
                        Text("Velg hva som skal skje med matloggene som allerede finnes på denne iPhonen. Klargjøring laster ned skyhistorikken.")
                        action("Aktiver med lokal historikk") { model.askToPrepare(.includeLocalHistory) }
                        action("Aktiver uten lokal historikk") { model.askToPrepare(.downloadOnly) }
                        Text("Innlogging alene aktiverer ikke overføring.")
                        } else {
                        Label("Matloggsynk er aktiv", systemImage: "icloud")
                        Text("Nye matlogger, redigeringer og slettinger synkroniseres når appen har nett. Offline-endringer beholdes til neste forsøk.")
                        action("Synkroniser") { model.askToSync() }
                        Button("Slå av matloggsynk") { model.askToDeactivate() }.frame(minHeight: 44)
                        }
                    }.padding(20).matLoggCardSurface()

                    if model.isBusy { ProgressView("Behandler matlogger …") }
                    if let message = model.message { Label(message, systemImage: "checkmark.circle") }
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(AppColors.errorText)
                    }
                    if !model.reviews.isEmpty {
                        Text("Gjennomgå avvik").font(AppTypography.title)
                        Text("Velg hvilken versjon du vil bruke. Ingen avvik løses automatisk.")
                        ForEach(model.reviews) { review in
                            VStack(alignment: .leading, spacing: 14) {
                                version("På denne iPhonen", value: review.local,
                                    absent: "Slettet på denne iPhonen")
                                Divider()
                                version("Sist hentet fra skyen", value: review.server?.payload,
                                    absent: review.server?.deleted == true ? "Slettet i skyen" : "Finnes ikke i skyen")
                                action(review.server?.deleted == true && review.local != nil ? "Behold lokalt som ny logg" : "Bruk mitt lokale valg") {
                                    model.askToResolve(review, choice: .useLocal)
                                }
                                action("Bruk skyversjonen") { model.askToResolve(review, choice: .useCloud) }
                            }.padding(20).matLoggCardSurface()
                        }
                    }
                } else {
                    Text("Krever et lokalt Supabase-testmiljø og innlogging med en testkonto. Synk må være åpnet for kontoen i testmiljøet.")
                }
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColors.ink)
            .padding(16)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Matlogger i skyen")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.action)
        .alert(confirmation?.title ?? "Bekreft", isPresented: Binding(
            get: { model.confirmation != nil }, set: { if !$0 { model.confirmation = nil } }
        )) {
            Button("Bekreft") {
                Task { await model.confirm(confirmation) }
            }
            Button("Avbryt", role: .cancel) { model.confirmation = nil }
        } message: { Text(confirmation?.message ?? "") }
    }
    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(title, action: perform)
            .frame(minHeight: 44, alignment: .leading)
            .disabled(model.isBusy)
    }
    private func version(_ title: String, value: CloudLogAggregate?, absent: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AppTypography.bodyEmphasis)
            if let value {
                Text(value.product.name)
                Text("\(value.log.amountG.formatted()) \(value.log.resolvedAmountUnit.rawValue) · \(value.log.mealType)")
                    .accessibilityLabel("\(value.log.amountG.formatted()) \(value.log.resolvedAmountUnit.spokenName), \(value.log.mealType)")
                Text(value.log.loggedDate, style: .date).foregroundStyle(AppColors.textSecondary)
                Text(value.log.loggedTime, style: .time).foregroundStyle(AppColors.textSecondary)
                DisclosureGroup("Næringsverdier og kilde") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Energi: \(value.log.calories.formatted()) kcal")
                        Text("Protein: \(value.log.proteinG.formatted()) g")
                        Text("Karbohydrat: \(value.log.carbsG.formatted()) g")
                        Text("Fett: \(value.log.fatG.formatted()) g")
                        Text("Kilde: \(sourceLabel(value.log.nutritionSource))")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 44)
            } else { Text(absent).foregroundStyle(AppColors.textSecondary) }
        }.accessibilityElement(children: .contain)
    }
    private func sourceLabel(_ source: NutritionSource?) -> String {
        switch source {
        case .matvaretabellen: "Matvaretabellen"
        case .openFoodFacts: "Open Food Facts"
        case .user: "Brukerregistrert"
        case nil: "Ukjent"
        }
    }
}
