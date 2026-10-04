import SwiftUI

struct HelpSupportView: View {
    @Environment(\.openURL) private var openURL
    @State private var showEmailUnavailable = false

    private let contactAddress = "nithusank.2002@gmail.com"

    var body: some View {
        Form {
            Section("Vanlige spørsmål") {
                answer("Hvordan logger jeg mat?", text: "Trykk på Loggfør i bunnmenyen. Søk etter en matvare, skann en strekkode eller legg inn mat manuelt. Velg mengde, måltid og dato før du lagrer.")
                answer("Hvordan endrer jeg en registrering?", text: "Åpne måltidet på Hjem og trykk på innslaget du vil endre. Juster registreringen og lagre endringene.")
                answer("Hva gjør jeg hvis matvaren mangler?", text: "Prøv å søke etter varen. Hvis du ikke finner den, kan du legge den inn manuelt. Bruk næringsverdiene fra emballasjen når du har dem.")
                answer("Kan jeg bruke MatLogg uten nett?", text: "Du kan logge mat med matvarer som finnes på enheten, og legge inn mat manuelt. Oppslag etter nye strekkoder og eksterne bilder trenger nett.")
                answer("Hvor lagres dataene mine?", text: "Matloggene dine lagres på denne enheten. Vi tilbyr ikke skybackup eller synkronisering mellom enheter. Data kan gå tapt hvis du sletter appen eller mister telefonen. En konto gir ikke skybackup.")
                answer("Hvordan eksporterer jeg data?", text: "Gå til Profil → Innstillinger → Data og lagring → Eksporter data. Eksporten er en JSON-kopi for innsyn og deling. Den kan ikke importeres tilbake i MatLogg.")
            }
            .listRowBackground(AppColors.surface)

            Section("Kontakt oss") {
                Button {
                    guard var components = URLComponents(string: "mailto:\(contactAddress)") else {
                        showEmailUnavailable = true
                        return
                    }
                    components.queryItems = [URLQueryItem(name: "subject", value: "MatLogg – hjelp og støtte")]
                    guard let url = components.url else {
                        showEmailUnavailable = true
                        return
                    }
                    openURL(url) { accepted in
                        if !accepted { showEmailUnavailable = true }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "envelope")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Send e-post")
                                .font(AppTypography.bodyEmphasis)
                            Text(contactAddress)
                                .font(AppTypography.secondary)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("help-send-email")
                .contextMenu {
                    ShareLink("Del e-postadresse", item: contactAddress)
                }
            }
            .listRowBackground(AppColors.surface)

            Section("Om MatLogg") {
                LabeledContent("Versjon", value: version)
                LabeledContent("Build", value: build)
                DisclosureGroup("Datakilder og lisenser") {
                    Text("Næringsdata kommer fra Matvaretabellen, Open Food Facts eller opplysninger du legger inn selv. Tallene kan inneholde feil eller være utdaterte. Kontroller emballasjen ved behov.")
                        .foregroundStyle(AppColors.textSecondary)
                    if let url = URL(string: "https://www.matvaretabellen.no") {
                        Link("Matvaretabellen", destination: url)
                    }
                    if let url = URL(string: "https://world.openfoodfacts.org") {
                        Link("Open Food Facts – bidragsytere", destination: url)
                    }
                    if let url = URL(string: "https://opendatacommons.org/licenses/odbl/1-0/") {
                        Link("Open Food Facts-database: ODbL", destination: url)
                    }
                    if let url = URL(string: "https://creativecommons.org/licenses/by-sa/3.0/") {
                        Link("Open Food Facts-bilder: CC BY-SA 3.0", destination: url)
                    }
                }
            }
            .listRowBackground(AppColors.surface)

            Section {
                Image("MatLoggLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .accessibilityHidden(true)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .font(AppTypography.body)
        .foregroundStyle(AppColors.deepInk)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .tint(AppColors.action)
        .matLoggTabBarScrollClearance()
        .navigationTitle("Hjelp og støtte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("Kunne ikke åpne e-postappen", isPresented: $showEmailUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Du kan sende e-post til \(contactAddress) fra en annen e-postapp. Hold inne kontaktraden og velg Del e-postadresse for å kopiere adressen fra delingsarket.")
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Ukjent"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Ukjent"
    }

    private func answer(_ question: String, text: String) -> some View {
        // Keep the question and answer in one Form row so expanded content
        // cannot introduce separately indented row separators.
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                Text(text)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } label: {
                Text(question)
                    .font(AppTypography.bodyEmphasis)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in dimensions.width }
    }
}
