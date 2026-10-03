import Foundation
import SQLite3
import Testing
@testable import MatLogg

@MainActor
struct PortionLoggingTests {
    @Test func understandableAmountSummaryTracksSelectionAndInvalidInput() {
        let serving = ServingOption(label: "1 beger · 150 g", grams: 150, source: .user,
                                    kind: .piece, shortLabel: "beger")
        let model = AmountSelectionViewModel(unit: .grams, servings: [serving])
        model.select(serving)
        #expect(model.amountSummary == "1 beger · 150 g")
        model.text = "0,5"
        #expect(model.amountSummary == "0,5 beger · 75 g")
        model.select(nil)
        #expect(model.amountSummary == "75 g")
        model.text = "0"
        #expect(model.amountSummary == nil)
        let liquid = AmountSelectionViewModel(unit: .milliliters, amount: 250)
        #expect(liquid.amountSummary == "250 ml")
    }

    @Test func documentedSingularNamesRemainConservative() {
        #expect(ServingOption.documentedLabel("1 beger · 150 g") == "beger")
        #expect(ServingOption.documentedLabel("1 beger (150 g)") == "beger")
        #expect(ServingOption.documentedLabel("2 beger · 300 g") == "porsjon")
        #expect(ServingOption.documentedLabel("150 g") == "porsjon")
        #expect(ServingOption.documentedLabel("1 · 150 g") == "porsjon")
    }
    private func serving(_ amount: Double = 37.5, unit: AmountUnit = .grams) -> ServingOption {
        ServingOption(label: "1 Polarbrød (37,5 g)", grams: amount, unit: unit,
                      source: .openFoodFacts, kind: .piece, shortLabel: "Polarbrød")
    }
    private func product() -> Product {
        Product(id: UUID(), name: "Porsjonstest", brand: nil, category: nil, barcodeEan: nil,
                source: "openfoodfacts", kind: .packaged, caloriesPer100g: 260,
                proteinGPer100g: 10, carbsGPer100g: 40, fatGPer100g: 4,
                sugarGPer100g: nil, fiberGPer100g: nil, sodiumMgPer100g: nil,
                imageUrl: nil, servings: [serving()], nutritionSource: .openFoodFacts,
                imageSource: .none, verificationStatus: .unverified, isVerified: false, createdAt: Date())
    }
    private func withDatabase(_ operation: (LocalStore, DatabaseService, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("portions.sqlite")
        let store = try LocalStore(databaseURL: url)
        try await operation(store, DatabaseService(store: store), url)
    }

    @Test func twoPiecesAndHalfPortionUseExactTotal() {
        let option = serving()
        let model = AmountSelectionViewModel(unit: .grams, servings: [option])
        model.select(option)
        #expect(model.amount == 37.5)
        model.step(1)
        #expect(model.amount == 75)
        #expect(model.portion?.count == 2)
        model.text = "0,5"
        #expect(model.amount == 18.75)
        model.text = "0.5"
        #expect(model.amount == 18.75)
        #expect(!model.canDecrease)
        model.step(-1)
        #expect(model.amount == 18.75)
    }

    @Test func unitSwitchAndFractionKeepPrecision() {
        let option = serving(3)
        let model = AmountSelectionViewModel(unit: .grams, servings: [option])
        model.select(option)
        model.select(nil)
        model.text = "10"
        model.select(option)
        #expect(abs((model.amount ?? 0) - 10) < 0.000001)
        model.select(nil)
        #expect(abs((model.amount ?? 0) - 10) < 0.000001)
        #expect(model.portion == nil)
        model.text = "0,00001"
        model.select(option)
        #expect(model.isValid)
        #expect(abs((model.amount ?? 0) - 0.00001) < 0.00000001)
    }

    @Test func rejectsInvalidTextOverflowAndIncompatibleHeuristics() {
        let legacy = ServingOption(label: "1 bar (500 g)", grams: 500, source: .heuristic)
        let model = AmountSelectionViewModel(unit: .grams, servings: [legacy, serving(250, unit: .milliliters)])
        #expect(model.servings.isEmpty)
        for text in ["", "0", "-1", "NaN", "inf", "1.2.3", "10001", "1e99"] {
            model.text = text
            #expect(!model.isValid)
        }
        model.select(serving())
        model.text = "999999999999999999999999"
        #expect(!model.isValid)
        model.select(nil)
        model.text = "10000"
        #expect(model.isValid)
    }

    @Test func millilitersAndRefreshUseSnapshot() {
        let option = serving(250, unit: .milliliters)
        let model = AmountSelectionViewModel(unit: .milliliters, servings: [option])
        model.select(option)
        model.step(1)
        model.updateServings([serving(300, unit: .milliliters)])
        #expect(model.amount == 500)
        #expect(model.portion?.amountPerServing == 250)
        model.restore(amount: 500, portion: model.portion)
        #expect(model.selectedServing == nil) // future logging must not restore an obsolete conversion
        #expect(model.amount == 500)
    }

    @Test func historicalLogSurvivesReopenEditCopyUndoAndSavedMeal() async throws {
        try await withDatabase { store, database, url in
            let owner = UUID()
            let item = product()
            try store.cacheCatalogProduct(item)
            let amount = AmountSelectionViewModel(unit: .grams, servings: item.servings ?? [])
            amount.select(try #require(item.servings?.first))
            amount.step(1)
            let snapshot = try #require(amount.portion)
            let vm = LogViewModel(repository: database)
            #expect(await vm.logFood(product: item, amountG: 75, mealType: "frokost", userId: owner, portionSelection: snapshot))
            let log = try #require(store.getAllLogs(userId: owner).first)
            #expect(log.calories == 195)
            let reopened = try LocalStore(databaseURL: url)
            #expect(reopened.getAllLogs(userId: owner).first?.portionSelection == snapshot)
            let payload = try #require(JSONSerialization.jsonObject(with: store.fetchPendingEvents(limit: 20)[0].payload) as? [String: Any])
            #expect((payload["portionSelection"] as? [String: Any])?["count"] as? Double == 2)
            let editor = EditLogViewModel(log: log)
            editor.amount.step(1)
            #expect(await editor.save { total, meal, portion in
                await vm.updateLog(log, amountG: total, mealType: meal, userId: owner, portionSelection: portion)
            })
            let edited = try #require(store.getAllLogs(userId: owner).first)
            #expect(edited.portionSelection?.count == 3)
            #expect(edited.amountG == 112.5)
            #expect(edited.calories == 292.5)
            #expect(await vm.updateLog(edited, amountG: 112.5, mealType: "lunsj", userId: owner))
            #expect(store.getAllLogs(userId: owner).first?.portionSelection?.count == 3)
            #expect(await vm.deleteWithUndo(edited, userId: owner))
            #expect(await vm.undoDeletion(userId: owner))
            let restored = try #require(store.getAllLogs(userId: owner).first)
            #expect(restored.portionSelection?.count == 3)
            let meals = SavedMealsViewModel(savedMealRepository: database, foodLogRepository: database,
                                            photoRepository: LocalMealPhotoRepository())
            await meals.load(userId: owner)
            #expect(await meals.saveFromLogs(name: "Testmåltid", mealType: "frokost", logs: [restored], userId: owner))
            let meal = try #require(store.getSavedMeals(userId: owner).first)
            #expect(meal.items.first?.portionSelection?.count == 3)
            #expect(await meals.log(meal, mealType: "middag", date: Date(), amounts: [meal.items[0].id: 75], userId: owner))
            #expect(store.getAllLogs(userId: owner).first(where: { $0.mealType == "middag" })?.portionSelection?.count == 2)
            #expect(await vm.updateLog(restored, amountG: 100, mealType: "lunsj", userId: owner, clearPortion: true))
            let direct = try #require(store.getAllLogs(userId: owner).first(where: { $0.id == restored.id }))
            #expect(direct.portionSelection == nil)
            let directEvent = try #require(store.fetchPendingEvents(limit: 50).last)
            let directPayload = try #require(JSONSerialization.jsonObject(with: directEvent.payload) as? [String: Any])
            #expect(directPayload["portionSelection"] is NSNull)
        }
    }

    @Test func copyAndYesterdayReusePreserveAndScalePortion() async throws {
        try await withDatabase { store, database, _ in
            let owner = UUID()
            let item = product()
            try store.cacheCatalogProduct(item)
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
            let portion = PortionSelection(servingId: UUID(), label: "Polarbrød", count: 2,
                amountPerServing: 37.5, unit: .grams, source: .openFoodFacts, kind: .piece)
            let vm = LogViewModel(repository: database)
            #expect(await vm.logFood(product: item, amountG: 75, mealType: "frokost", userId: owner,
                date: yesterday, portionSelection: portion))
            let reuse = MealReuseViewModel(repository: database)
            await reuse.load(userId: owner, date: today)
            let suggestion = try #require(reuse.suggestions.first)
            reuse.edit(suggestion)
            reuse.setAmount(itemId: suggestion.items[0].id, text: "112,5")
            #expect(await reuse.logDraft())
            let todayLog = try #require(store.getAllLogs(userId: owner).first(where: { Calendar.current.isDate($0.loggedDate, inSameDayAs: today) }))
            #expect(todayLog.portionSelection?.count == 3)
            let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: today))
            #expect(await vm.copyLogs(from: today, to: tomorrow, userId: owner))
            let copy = try #require(store.getAllLogs(userId: owner).first(where: { Calendar.current.isDate($0.loggedDate, inSameDayAs: tomorrow) }))
            #expect(copy.portionSelection == todayLog.portionSelection)
            #expect(copy.id != todayLog.id)
        }
    }

    @Test func exportsHistoricalPortionAndRemembersOnlyMatchingLastChoice() async throws {
        try await withDatabase { store, database, _ in
            let owner = UUID()
            let item = product()
            let amount = AmountSelectionViewModel(unit: .grams, servings: item.servings ?? [])
            amount.select(try #require(item.servings?.first))
            amount.step(1)
            let portion = try #require(amount.portion)
            #expect(await LogViewModel(repository: database).logFood(product: item, amountG: 75,
                mealType: "frokost", userId: owner, portionSelection: portion))
            let suite = "matlogg.portion.fixture.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = PreferencesViewModel(defaults: defaults)
            preferences.setLastUsedAmount(75, for: item.id, userId: owner)
            preferences.setLastUsedPortion(portion, for: item.id, userId: owner)
            let restored = AmountSelectionViewModel(unit: .grams, servings: item.servings ?? [])
            restored.restore(amount: 75, portion: preferences.lastUsedPortion(for: item.id, userId: owner))
            #expect(restored.portion == portion)
            #expect(preferences.lastUsedPortion(for: item.id, userId: UUID()) == nil)
            let exporter = UserDataExportService(logRepository: database, savedMealRepository: database,
                waterRepository: database, healthRepository: database, productRepository: database,
                personalDetailsStore: UserDefaultsPersonalDetailsStore(defaults: defaults), profileDataRepository: database)
            let url = try #require(await exporter.export(for: .local(id: owner)))
            defer { exporter.removeExport(at: url) }
            let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let logs = try #require(json["logs"] as? [[String: Any]])
            let exported = try #require(logs.first?["portion_selection"] as? [String: Any])
            #expect(exported["count"] as? Double == 2)
            #expect(exported["amountPerServing"] as? Double == 37.5)
            #expect(exported["label"] as? String == "Polarbrød")
            #expect(store.getAllLogs(userId: owner).count == 1)
        }
    }

    @Test func oldJSONAndFailedSaveKeepSafeState() async throws {
        let item = product()
        let log = FoodLog(userId: UUID(), productId: item.id, mealType: "frokost", amountG: 75,
                          loggedDate: Date(), calories: 195, proteinG: 7.5, carbsG: 30, fatG: 3)
        let decoded = try JSONDecoder().decode(FoodLog.self, from: JSONEncoder().encode(log))
        #expect(decoded.portionSelection == nil)
        let editor = EditLogViewModel(log: decoded)
        editor.amount.text = "90"
        #expect(!(await editor.save { _, _, _ in false }))
        #expect(editor.amount.amount == 90)
        #expect(editor.error != nil)
        #expect(await editor.save { _, _, _ in true })
    }

    @Test func eventFailureRollsBackPortionAndLogAndRetryIsSafe() async throws {
        try await withDatabase { store, _, url in
            let selection = PortionSelection(servingId: UUID(), label: "Polarbrød", count: 2,
                                             amountPerServing: 37.5, unit: .grams, source: .openFoodFacts, kind: .piece)
            let owner = UUID()
            let log = FoodLog(userId: owner, productId: UUID(), mealType: "frokost", amountG: 75,
                              portionSelection: selection, loggedDate: Date(), calories: 195, proteinG: 7.5, carbsG: 30, fatG: 3)
            var db: OpaquePointer?
            #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
            defer { sqlite3_close(db) }
            #expect(sqlite3_exec(db, "CREATE TRIGGER fail_portion BEFORE INSERT ON sync_queue BEGIN SELECT RAISE(ABORT, 'fixture'); END;", nil, nil, nil) == SQLITE_OK)
            #expect(throws: (any Error).self) { try store.saveLog(log) }
            #expect(store.getAllLogs(userId: owner).isEmpty)
            #expect(store.fetchPendingEvents(limit: 10).isEmpty)
            #expect(sqlite3_exec(db, "DROP TRIGGER fail_portion;", nil, nil, nil) == SQLITE_OK)
            try store.saveLog(log)
            #expect(store.getAllLogs(userId: owner).first?.portionSelection == selection)
            #expect(store.fetchPendingEvents(limit: 10).count == 1)
        }
    }
}

@MainActor
struct PortionImportTests {
    @Test func documentedPiecesAndPackageWeightRemainDistinctAndStable() async throws {
        let api = APIService(httpClient: PortionHTTPFixture(), catalogRetryLimit: 0)
        let first = try #require(try await api.searchProductsByNameOpenFoodFacts("fixture").first)
        let second = try #require(try await api.searchProductsByNameOpenFoodFacts("fixture").first)
        #expect(first.servings?.map(\.id) == second.servings?.map(\.id))
        let options = try #require(first.servings)
        #expect(options[0].portionLabel == "Polarbrød")
        #expect(options[0].grams == 37.5)
        #expect(options[0].kind == .piece)
        #expect(options[1].kind == .package)
        #expect(options[1].grams == 300)
        #expect(options[2].selectableKind == nil)
        let all = try await api.searchProductsByNameOpenFoodFacts("fixture")
        let packageOnly = all[1]
        #expect(packageOnly.servings?.first?.kind == .package)
        #expect(packageOnly.servings?.first?.portionLabel == "hel pakke")
        #expect(packageOnly.servings?.contains(where: { $0.kind == .piece }) == false)
        #expect(all[2].servings == nil) // name alone never establishes a portion
    }
}

private struct PortionHTTPFixture: HTTPClientProtocol {
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        let nutrient: [String: Any] = ["energy-kcal_100g": 260, "proteins_100g": 10, "carbohydrates_100g": 40, "fat_100g": 4]
        let products: [[String: Any]] = [
            ["code": "fixture-a", "product_name": "Fixture bread", "serving_size": "1 Polarbrød (37,5 g)",
             "product_quantity": 300, "product_quantity_unit": "g", "nutriments": nutrient],
            ["code": "fixture-b", "product_name": "Fixture bar", "product_quantity": 500,
             "product_quantity_unit": "g", "nutriments": nutrient],
            ["code": "fixture-c", "product_name": "Fixture bar 500 g", "nutriments": nutrient],
        ]
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        return HTTPClientResponse(data: try JSONSerialization.data(withJSONObject: ["products": products]), response: response)
    }
}
