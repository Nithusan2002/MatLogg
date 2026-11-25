import Foundation

nonisolated enum MascotClip: String, CaseIterable, Identifiable, Sendable {
    case idle, greeting, walk
    var id: String { rawValue }
    var title: String {
        switch self { case .idle: "Hvile"; case .greeting: "Hilsen"; case .walk: "Gange" }
    }
}

nonisolated struct MascotAsset: Sendable {
    let url: URL
    let duration: Double
}

nonisolated enum MascotAssetError: LocalizedError {
    case unavailable, invalidManifest
    var errorDescription: String? { "Maskotressursen mangler eller har feil format." }
}

nonisolated protocol MascotAssetProviding: Sendable {
    func asset(for clip: MascotClip) async throws -> MascotAsset
}

nonisolated struct BundledMascotAssetRepository: MascotAssetProviding {
    let directory: URL?

    nonisolated func asset(for clip: MascotClip) async throws -> MascotAsset {
        let directory = directory
        return try await Task.detached(priority: .userInitiated) {
            struct Manifest: Decodable {
                struct Entry: Decodable { let file: String; let duration: Double }
                let schemaVersion: Int
                let clips: [String: Entry]
            }
            guard let directory else { throw MascotAssetError.unavailable }
            let manifest = try JSONDecoder().decode(Manifest.self,
                from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
            guard manifest.schemaVersion == 1, let entry = manifest.clips[clip.rawValue],
                  entry.duration.isFinite, entry.duration > 0,
                  entry.file == URL(fileURLWithPath: entry.file).lastPathComponent,
                  entry.file.hasSuffix(".usdz") else { throw MascotAssetError.invalidManifest }
            let url = directory.appendingPathComponent(entry.file)
            guard FileManager.default.fileExists(atPath: url.path) else { throw MascotAssetError.unavailable }
            return MascotAsset(url: url, duration: entry.duration)
        }.value
    }
}

@MainActor protocol MascotPlaying: AnyObject {
    func prepare(_ asset: MascotAsset) async throws
    func resume(playing: Bool)
    func suspend()
    func restart(playing: Bool)
}
