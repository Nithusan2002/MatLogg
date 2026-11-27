#if DEBUG
import Foundation

/// Fails one read, then delegates to the real QA store. It never changes stored data.
@MainActor
final class FavoriteReadFailureQAFixture: FavoriteListRepository {
    private let base: any FavoriteListRepository
    private var shouldFail = true

    init(base: any FavoriteListRepository) { self.base = base }

    func getFavorites(userId: UUID, kind: ProductKind?) async throws -> [Product] {
        if shouldFail {
            shouldFail = false
            throw DatabaseServiceError.unavailable
        }
        return try await base.getFavorites(userId: userId, kind: kind)
    }
}
#endif
