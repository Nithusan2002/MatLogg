import Foundation
import Testing
@testable import MatLogg

@MainActor
struct FoodSearchRequestLifecycleTests {
    @Test func repeatedSubmitDoesNotRestartAnActiveSearch() async {
        let repository = LifecycleSearchRepository()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("melk")
        vm.search()
        await repository.waitForRequests(1)
        vm.search()
        for _ in 0..<20 { await Task.yield() }
        #expect(repository.requests.count == 1)
        for request in repository.requests { request.resume(returning: []) }
        await waitUntil { vm.phase == .complete }
        #expect(repository.requests.count == 1)
    }

    @Test func queryChangeDiscardsAnOlderFailureAndClearsSlowFeedback() async {
        let repository = LifecycleSearchRepository()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("melk")
        vm.search()
        await repository.waitForRequests(1)
        vm.setQuery("havre")
        vm.search()
        await repository.waitForRequests(2)
        repository.requests[1].resume(returning: [product("Havre")])
        await waitUntil { vm.phase == .complete }
        repository.requests[0].resume(throwing: APIService.APIError.serverError(503))
        for _ in 0..<10 { await Task.yield() }
        #expect(vm.query == "havre")
        #expect(vm.phase == .complete)
        #expect(vm.searchError == nil)
        #expect(!vm.showsSlowSearchFeedback)
        #expect(vm.results.map(\.name) == ["Havre"])
    }

    @Test func slowStatusClearsWhenSearchIsSuspended() async throws {
        let repository = LifecycleSearchRepository()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("melk")
        vm.search()
        await repository.waitForRequests(1)
        try await Task.sleep(for: .milliseconds(2_100))
        #expect(vm.showsSlowSearchFeedback)
        vm.suspend()
        #expect(!vm.showsSlowSearchFeedback)
        repository.requests[0].resume(returning: [])
        for _ in 0..<10 { await Task.yield() }
        #expect(vm.phase == .local)
        #expect(vm.searchError == nil)
    }

    private func product(_ name: String) -> Product {
        Product(name: name, caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
    }
    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(predicate())
    }
}

@MainActor
private final class LifecycleSearchRepository: FoodSearchRepository {
    var requests: [CheckedContinuation<[Product], Error>] = []
    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        FoodSearchLibrary(products: [], recent: [], favorites: [], suggestions: [])
    }
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary { try await loadLocalLibrary(owner: owner) }
    func searchRemote(query: String, owner: UUID?, scope: FoodSearchScope) async throws -> [Product] {
        try await withCheckedThrowingContinuation { requests.append($0) }
    }
    func saveManual(_ product: Product, owner: UUID) async throws {}
    func prepare(_ product: Product, owner: UUID) async throws {}
    func waitForRequests(_ count: Int) async {
        for _ in 0..<1_000 {
            if requests.count >= count { return }
            await Task.yield()
        }
        #expect(requests.count >= count)
    }
}
