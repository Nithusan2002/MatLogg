import Foundation
import Combine

@MainActor
protocol UserDataExporting {
    func export(for user: User) async -> URL?
    func removeExport(at url: URL)
}

@MainActor
final class ProfileExportViewModel: ObservableObject {
    struct Document: Identifiable {
        let id = UUID()
        let url: URL
    }
    @Published private(set) var isExporting = false
    @Published private(set) var errorMessage: String?
    @Published var document: Document?
    private let exporter: any UserDataExporting
    private var generation = 0
    private var exportedURL: URL?

    init(exporter: any UserDataExporting) { self.exporter = exporter }

    func export(user: User?) async {
        guard !isExporting else { return }
        clearDocument()
        errorMessage = nil
        guard let user else {
            errorMessage = "Åpne skjermen på nytt når en profil er aktiv."
            return
        }
        isExporting = true
        let requestGeneration = generation
        defer { isExporting = false }
        let result = await exporter.export(for: user)
        guard requestGeneration == generation, !Task.isCancelled else {
            if let result { exporter.removeExport(at: result) }
            return
        }
        guard let url = result else {
            errorMessage = "Kunne ikke klargjøre eksporten. Prøv igjen. Dataene dine er fortsatt lagret på enheten."
            return
        }
        exportedURL = url
        document = Document(url: url)
    }

    func clearDocument() {
        if let exportedURL { exporter.removeExport(at: exportedURL) }
        exportedURL = nil
        document = nil
    }

    func reset() {
        generation += 1
        clearDocument()
        errorMessage = nil
    }
}
