#if DEBUG
import SwiftUI

/// Disposable signed-in UI fixture. The normal screens/store are used with synthetic transport.
struct CloudLogQARoot: View {
    private let database: DatabaseService?
    private let repository: (any CloudLogRepository)?
    private let defaults: UserDefaults?
    private let owner = UUID()
    @StateObject private var mode: DemoMode

    init() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-ui-\(UUID())")
        let defaults = UserDefaults(suiteName: "cloud-ui-\(UUID())")
        self.defaults = defaults
        _mode = StateObject(wrappedValue: DemoMode(demoDefaults: nil, directory: directory))
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try LocalStore(databaseURL: directory.appendingPathComponent("ui.sqlite"))
            let database = DatabaseService(store: store, defaults: defaults ?? .standard)
            let product = Product(name: "Synktest eple", caloriesPer100g: 50, proteinGPer100g: 1, carbsGPer100g: 10, fatGPer100g: 0, nutritionSource: .user)
            try store.saveProduct(product, ownerUserId: owner)
            try store.saveLog(FoodLog(userId: owner, productId: product.id, mealType: "frokost", amountG: 100, loggedDate: Date(), calories: 50, proteinG: 1, carbsG: 10, fatG: 0))
            self.database = database
            repository = database.makeDevelopmentCloudLogRepository(transport: CloudLogUITransport(), uploadPolicy: .integrationTesting)
            if let defaults { AuthService(defaults: defaults).setOnboardingCompleted(true, userId: owner) }
        } catch { database = nil; repository = nil }
    }
    var body: some View {
        if let database, let defaults {
            MatLoggContent(databaseService: database, defaults: defaults, accountRepository: CloudLogUIAuth(owner: owner), cloudRepositoryForQA: repository)
                .environmentObject(mode)
        } else { Text("Kunne ikke starte isolert synktest") }
    }
}

private final class CloudLogUIAuth: AccountAuthRepository {
    let owner: UUID
    init(owner: UUID) { self.owner = owner }
    func restoreSession() async -> User? { User(id: owner, email: "synthetic@example.invalid", firstName: "Synktest", lastName: "", authProvider: "email", createdAt: Date()) }
    func signIn(email: String, password: String) async throws -> User { throw CloudLogError.disabled }
    func signUp(email: String, password: String) async throws -> AccountRegistrationResult { throw CloudLogError.disabled }
    func resendEmailVerification(to email: String) async throws { throw CloudLogError.disabled }
    func signInWithApple(identityToken: String, nonce: String) async throws -> User { throw CloudLogError.disabled }
    func handleAuthCallback(_ url: URL) async throws -> User { throw CloudLogError.disabled }
    func signOut() async throws {}
    func deleteAccount() async throws -> AccountDeletionReceipt { throw CloudLogError.disabled }
}

private actor CloudLogUITransport: CloudLogTransport {
    let epoch = UUID()
    var changes: [CloudLogChange] = []
    var receipts: [UUID: CloudLogReceipt] = [:]
    var snapshots: [UUID: [CloudLogChange]] = [:]
    func head(owner: UUID) -> CloudLogHead { CloudLogHead(owner: owner, historyEpoch: epoch, cursor: Int64(changes.count)) }
    func beginBootstrap(_ plan: CloudLogBootstrapPlan) -> CloudLogBootstrapManifest {
        var latest: [UUID: CloudLogChange] = [:]
        for change in changes { latest[change.entityId] = change }
        let rows = latest.values.sorted { $0.entityId.uuidString < $1.entityId.uuidString }
        snapshots[plan.snapshotId] = rows
        return CloudLogBootstrapManifest(owner: plan.owner, snapshotId: plan.snapshotId, historyEpoch: epoch, upperCursor: Int64(changes.count), totalCount: rows.count)
    }
    func readBootstrap(_ plan: CloudLogBootstrapPlan) throws -> CloudLogBootstrapPage {
        guard let rows = snapshots[plan.snapshotId], let manifest = plan.manifest else { throw CloudLogError.invalidResponse }
        let page = Array(rows.dropFirst(plan.offset).prefix(100))
        return CloudLogBootstrapPage(owner: plan.owner, snapshotId: plan.snapshotId, historyEpoch: epoch, upperCursor: manifest.upperCursor, totalCount: rows.count, offset: plan.offset, changes: page, complete: plan.offset + page.count == rows.count)
    }
    func pull(after cursor: Int64, epoch: UUID, owner: UUID) -> CloudLogPage {
        let page = Array(changes.filter { $0.revision > cursor }.prefix(100))
        return CloudLogPage(owner: owner, changes: page, cursor: page.last?.revision ?? cursor, historyEpoch: epoch)
    }
    func push(_ mutation: CloudLogMutation, owner: UUID) throws -> CloudLogReceipt {
        if let receipt = receipts[mutation.eventId] { return receipt }
        try mutation.payload?.validate(owner: owner, id: mutation.entityId)
        let change = CloudLogChange(entityId: mutation.entityId, revision: Int64(changes.count + 1), deleted: mutation.payload == nil, payload: mutation.payload)
        changes.append(change)
        let receipt = CloudLogReceipt(eventId: mutation.eventId, status: "applied", change: change, historyEpoch: epoch)
        receipts[mutation.eventId] = receipt
        return receipt
    }
}
#endif
