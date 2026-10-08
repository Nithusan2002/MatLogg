import Foundation
import Testing
@testable import MatLogg

@Suite(.serialized)
@MainActor
struct ProductSearchTests {
    @Test func nameSearchUsesSelectedCountryOrGlobalEndpoint() async throws {
        SearchURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            #expect(["no.openfoodfacts.org", "world.openfoodfacts.org"].contains(url.host ?? ""))
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            let name = url.host == "no.openfoodfacts.org" ? "Norway" : "Global"
            let body = "{\"products\":[{\"code\":\"123\",\"product_name\":\"" + name + "\",\"nutriments\":{\"energy-kcal_100g\":100,\"proteins_100g\":2,\"carbohydrates_100g\":10,\"fat_100g\":4}}]}"
            return (response, Data(body.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(httpClient: URLSessionHTTPClient(session: URLSession(configuration: configuration)), catalogRetryLimit: 0)
        let norwegian = try await service.searchProductsByNameOpenFoodFacts("havre")
        let global = try await service.searchProductsByNameOpenFoodFacts("havre", scope: .global)
        #expect(norwegian.first?.name == "Norway")
        #expect(global.first?.name == "Global")
    }

    @Test func matvaretabellenParserUsesOfficialNutrientIdsAndDoesNotInventMissingMacros() throws {
        let data = Data(#"""
        {
          "foods": [
            {
              "foodId": "06.178",
              "foodName": "Adzukibønner, tørr",
              "foodGroupId": "12",
              "calories": { "quantity": 310 },
              "constituents": [
                { "nutrientId": "Protein", "quantity": 22.1 },
                { "nutrientId": "Karbo", "quantity": 45.6 },
                { "nutrientId": "Fett", "quantity": 1.4 },
                { "nutrientId": "Fiber", "quantity": 12.7 },
                { "nutrientId": "Mono+Di", "quantity": 2.1 },
                { "nutrientId": "Na", "quantity": 4, "unit": "mg" }
              ]
            },
            {
              "foodId": "missing-fat",
              "foodName": "Ufullstendig",
              "calories": { "quantity": 20 },
              "constituents": [
                { "nutrientId": "Protein", "quantity": 1 },
                { "nutrientId": "Karbo", "quantity": 2 }
              ]
            }
          ]
        }
        """#.utf8)

        let products = MatvaretabellenResponseParser.parse(data: data)
        let product = try #require(products.first)

        #expect(products.count == 1)
        #expect(product.id == "06.178")
        #expect(product.carbsGPer100g == 45.6)
        #expect(product.fiberGPer100g == 12.7)
        #expect(product.sodiumMgPer100g == 4)
    }

    @Test func bundledMatvaretabellenCatalogIsSearchedLocally() async throws {
        let item = MatvaretabellenProduct(
            id: "1",
            name: "Havregryn",
            brand: nil,
            category: "Korn",
            caloriesPer100g: 370,
            proteinGPer100g: 13,
            carbsGPer100g: 60,
            fatGPer100g: 7,
            sugarGPer100g: nil,
            fiberGPer100g: 10,
            sodiumMgPer100g: nil
        )
        let data = try JSONEncoder().encode([item])
        let service = MatvaretabellenService(bundledData: { data })

        let products = try await service.searchProducts(query: "havre")

        #expect(products.map(\.id) == ["1"])
    }

    @Test func productionMatvaretabellenSnapshotLoadsFromAppBundle() async throws {
        let products = try await MatvaretabellenService().fetchCommonFoods()

        #expect(products.count >= 2_000)
        #expect(products.contains { $0.id == "06.178" && $0.sodiumMgPer100g == 5 })
    }

    @Test func freshBarcodeCacheDoesNotRevalidate() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cached = makeCachedBarcodeProduct(name: "Fersk", fetchedAt: now.addingTimeInterval(-60))
        let repository = ProductRepositorySpy(product: cached)
        let barcodeService = BarcodeServiceSpy(result: .success(cached))
        let viewModel = makeProductViewModel(
            repository: repository,
            barcodeService: barcodeService,
            now: now
        )

        let refreshed = await viewModel.refreshCachedProductIfNeeded(cached)

        #expect(refreshed == nil)
        #expect(await barcodeService.callCount == 0)
        #expect(repository.cachedProducts.isEmpty)
    }

    @Test func staleBarcodeCacheReturnsOneSharedBackgroundRefresh() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cached = makeCachedBarcodeProduct(
            name: "Gammel",
            fetchedAt: now.addingTimeInterval(-31 * 24 * 60 * 60)
        )
        let refreshed = makeCachedBarcodeProduct(name: "Oppdatert", fetchedAt: now)
        let repository = ProductRepositorySpy(product: cached)
        let barcodeService = BarcodeServiceSpy(result: .success(refreshed), delayNanoseconds: 30_000_000)
        let viewModel = makeProductViewModel(
            repository: repository,
            barcodeService: barcodeService,
            now: now
        )

        let firstTask = Task { await viewModel.refreshCachedProductIfNeeded(cached) }
        let secondTask = Task { await viewModel.refreshCachedProductIfNeeded(cached) }
        let first = await firstTask.value
        let second = await secondTask.value

        #expect(first?.name == "Oppdatert")
        #expect(second?.name == "Oppdatert")
        #expect(await barcodeService.callCount == 1)
        #expect(repository.cachedProducts.map(\.name) == ["Oppdatert"])
    }

    @Test func failedBarcodeRefreshUsesRetryBackoffAndKeepsCachedSnapshot() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cached = makeCachedBarcodeProduct(name: "Behold meg", fetchedAt: nil)
        let repository = ProductRepositorySpy(product: cached)
        let barcodeService = BarcodeServiceSpy(result: .failure(TestBarcodeError.offline))
        let viewModel = makeProductViewModel(
            repository: repository,
            barcodeService: barcodeService,
            now: now
        )

        let first = await viewModel.refreshCachedProductIfNeeded(cached)
        let second = await viewModel.refreshCachedProductIfNeeded(cached)

        #expect(first == nil)
        #expect(second == nil)
        #expect(await barcodeService.callCount == 1)
        #expect(repository.getProductByBarcode("1234567890123", ownerUserId: nil)?.name == "Behold meg")
        #expect(repository.cachedProducts.isEmpty)
    }

    @Test func refreshStartsAtExactlyThirtyDaysAndRetryExpiresAtTwentyFourHours() async throws {
        var now = Date(timeIntervalSince1970: 2_000_000_000)
        let fetchedAt = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let cached = makeCachedBarcodeProduct(name: "Gammel", fetchedAt: fetchedAt)
        let remote = BarcodeServiceSpy(result: .failure(TestBarcodeError.offline))
        let repository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: cached),
                                                       remote: remote, now: { now })
        #expect(!BarcodeProductCachePolicy.standard.needsRevalidation(cached, now: now.addingTimeInterval(-1)))
        #expect(BarcodeProductCachePolicy.standard.needsRevalidation(cached, now: now))
        do { _ = try await repository.refresh(cached, manually: false) } catch {}
        now = now.addingTimeInterval(24 * 60 * 60 - 1)
        #expect(try await repository.refresh(cached, manually: false) == nil)
        #expect(remote.callCount == 1)
        now = now.addingTimeInterval(1)
        do { _ = try await repository.refresh(cached, manually: false) } catch {}
        #expect(remote.callCount == 2)
    }

    @Test func manualRefreshBypassesFreshnessAndSharesAutomaticRequest() async throws {
        let now = Date()
        let cached = makeCachedBarcodeProduct(name: "Fersk", fetchedAt: now)
        let updated = makeCachedBarcodeProduct(name: "Ny", fetchedAt: now)
        let remote = BarcodeServiceSpy(result: .success(updated), delayNanoseconds: 30_000_000)
        let products = ProductRepositorySpy(product: cached)
        let repository = DefaultBarcodeLookupRepository(products: products, remote: remote, now: { now })
        let first = Task { try await repository.refresh(cached, manually: true) }
        let second = Task { try await repository.fetch(barcode: "1234567890123") }
        #expect(try await first.value?.name == "Ny")
        #expect(try await second.value.name == "Ny")
        #expect(remote.callCount == 1)
        #expect(products.cachedProducts.count == 1)
    }

    @Test func manualRefreshCanRetryNetworkFailureButCannotBypassProviderLimit() async throws {
        var now = Date()
        let cached = makeCachedBarcodeProduct(name: "Behold", fetchedAt: nil)
        let remote = BarcodeServiceSpy(result: .failure(APIService.APIError.rateLimited(retryAfterSeconds: 120)))
        let repository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: cached),
                                                       remote: remote, now: { now })
        do { _ = try await repository.refresh(cached, manually: true) } catch {}
        do { _ = try await repository.fetch(barcode: "different-barcode") } catch {
            #expect(BarcodeLookupFailure.classify(error) == .rateLimited(120))
        }
        #expect(remote.callCount == 1)
        now = now.addingTimeInterval(120)
        do { _ = try await repository.refresh(cached, manually: true) } catch {}
        #expect(remote.callCount == 2)

        let offline = BarcodeServiceSpy(result: .failure(TestBarcodeError.offline))
        let retryRepository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: cached), remote: offline)
        do { _ = try await retryRepository.refresh(cached, manually: false) } catch {}
        do { _ = try await retryRepository.refresh(cached, manually: true) } catch {}
        #expect(offline.callCount == 2)
    }

    @Test func reopeningOldSnapshotUsesFreshStoredCatalogWithoutAnotherRequest() async throws {
        let now = Date()
        let stale = makeCachedBarcodeProduct(name: "Gammel", fetchedAt: nil)
        let fresh = makeCachedBarcodeProduct(name: "Ny", fetchedAt: now)
        let remote = BarcodeServiceSpy(result: .success(fresh))
        let repository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: fresh), remote: remote, now: { now })
        #expect(try await repository.refresh(stale, manually: false)?.name == "Ny")
        #expect(remote.callCount == 0)
    }

    @Test func changedUnitDoesNotReinterpretAmountOnOpenProductCard() async {
        let cached = makeCachedBarcodeProduct(name: "Gram", fetchedAt: nil)
        let updated = Product(id: cached.id, name: "Milliliter", barcodeEan: cached.barcodeEan,
                              source: "openfoodfacts", caloriesPer100g: 100, proteinGPer100g: 4,
                              carbsGPer100g: 18, fatGPer100g: 3, nutritionSource: .openFoodFacts,
                              nutritionBasis: .per100ml, fetchedAt: Date())
        let products = ProductRepositorySpy(product: cached)
        let repository = DefaultBarcodeLookupRepository(products: products, remote: BarcodeServiceSpy(result: .success(updated)))
        let model = ProductDetailViewModel(product: cached, repository: repository)
        await model.refresh(manually: true)
        #expect(model.product.amountUnit == .grams)
        #expect(model.refreshMessage?.contains("måleenhet") == true)
        #expect(products.getProduct(cached.id)?.amountUnit == .milliliters)
    }

    @Test func refreshNeverReturnsAnotherOwnersPrivateSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BarcodeOwner-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let privateProduct = makeCachedBarcodeProduct(name: "Privat snapshot", fetchedAt: Date())
        try store.saveProduct(privateProduct, ownerUserId: UUID())
        let publicProduct = makeCachedBarcodeProduct(name: "Offentlig", fetchedAt: nil)
        let remote = BarcodeServiceSpy(result: .failure(TestBarcodeError.offline))
        let repository = DefaultBarcodeLookupRepository(products: DatabaseService(store: store), remote: remote)
        let result = try? await repository.refresh(publicProduct, manually: false)
        #expect(result == nil)
        #expect(remote.callCount == 1)
    }

    @Test func ownNutritionCannotBeManuallyOverwritten() async throws {
        let own = Product(name: "Min rettelse", barcodeEan: "1234567890123", source: "openfoodfacts",
                          caloriesPer100g: 150, proteinGPer100g: 4, carbsGPer100g: 18,
                          fatGPer100g: 3, nutritionSource: .user)
        let remote = BarcodeServiceSpy(result: .success(own))
        let repository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: own), remote: remote)
        #expect(try await repository.refresh(own, manually: true) == nil)
        #expect(remote.callCount == 0)
    }

    @Test func scanFailureDistinguishesUnknownIncompleteAndNetwork() async {
        for (error, expected) in [(APIService.APIError.serverError(404), BarcodeLookupFailure.notFound),
                                  (.incompleteProductData, .incomplete), (.serverError(503), .unavailable)] {
            let viewModel = makeProductViewModel(repository: ProductRepositorySpy(product: nil),
                                                barcodeService: BarcodeServiceSpy(result: .failure(error)), now: Date())
            await viewModel.scan(barcode: "1234567890123", ownerUserId: nil)
            #expect(viewModel.scanFailure == expected)
            #expect(viewModel.scannedProduct == nil)
            #expect(!viewModel.isScanning)
        }
    }

    @Test func dismissedScanCannotPublishDelayedResultOverManualChoice() async {
        let cached = makeCachedBarcodeProduct(name: "Forsinket", fetchedAt: Date())
        let remote = BarcodeServiceSpy(result: .success(cached), delayNanoseconds: 30_000_000)
        let viewModel = makeProductViewModel(repository: ProductRepositorySpy(product: nil), barcodeService: remote, now: Date())
        let task = Task { await viewModel.scan(barcode: "1234567890123", ownerUserId: nil) }
        while remote.callCount == 0 { await Task.yield() }
        viewModel.resetScan()
        let manual = Product(name: "Egen vare", source: "manual", caloriesPer100g: 10,
                             proteinGPer100g: 1, carbsGPer100g: 1, fatGPer100g: 0)
        viewModel.acceptManualScan(manual)
        await task.value
        #expect(viewModel.scannedProduct?.id == manual.id)
        #expect(viewModel.scanFailure == nil)
    }

    @Test func failedCacheWriteKeepsProductCardAndReportsLocalFailure() async {
        let cached = makeCachedBarcodeProduct(name: "Behold", fetchedAt: nil)
        let updated = makeCachedBarcodeProduct(name: "Ny", fetchedAt: Date())
        let products = ProductRepositorySpy(product: cached)
        products.cacheError = LocalStoreError.sqlite("synthetic failure")
        let repository = DefaultBarcodeLookupRepository(products: products, remote: BarcodeServiceSpy(result: .success(updated)))
        let model = ProductDetailViewModel(product: cached, repository: repository)
        await model.refresh(manually: true)
        #expect(model.product.name == "Behold")
        #expect(products.cachedProducts.isEmpty)
        #expect(model.refreshMessage == BarcodeLookupFailure.storageFailure.message)
    }

    @Test func productCardKeepsDataOnRefreshFailureAndUpdatesOnSuccess() async {
        let cached = makeCachedBarcodeProduct(name: "Behold", fetchedAt: Date())
        let failedRepository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: cached),
                                                             remote: BarcodeServiceSpy(result: .failure(TestBarcodeError.offline)))
        let failed = ProductDetailViewModel(product: cached, repository: failedRepository)
        await failed.refresh(manually: true)
        #expect(failed.product.name == "Behold")
        #expect(failed.refreshMessage == BarcodeLookupFailure.unavailable.message)
        #expect(!failed.isRefreshing)

        let updated = makeCachedBarcodeProduct(name: "Ny", fetchedAt: Date())
        let repository = DefaultBarcodeLookupRepository(products: ProductRepositorySpy(product: cached),
                                                       remote: BarcodeServiceSpy(result: .success(updated)))
        let model = ProductDetailViewModel(product: cached, repository: repository)
        await model.refresh(manually: true)
        #expect(model.product.name == "Ny")
        #expect(model.refreshMessage == "Produktdata er oppdatert.")
    }

    @Test func matvaretabellenNutritionIsNotDowngradedByBarcodeRefresh() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cached = Product(
            id: Product.catalogID(source: "openfoodfacts", externalID: "1234567890123"),
            name: "Matchet",
            barcodeEan: "1234567890123",
            source: "openfoodfacts",
            caloriesPer100g: 90,
            proteinGPer100g: 3,
            carbsGPer100g: 15,
            fatGPer100g: 2,
            nutritionSource: .matvaretabellen,
            imageSource: .openFoodFacts,
            fetchedAt: now.addingTimeInterval(-90 * 24 * 60 * 60)
        )
        let repository = ProductRepositorySpy(product: cached)
        let barcodeService = BarcodeServiceSpy(result: .success(cached))
        let viewModel = makeProductViewModel(
            repository: repository,
            barcodeService: barcodeService,
            now: now
        )

        let refreshed = await viewModel.refreshCachedProductIfNeeded(cached)

        #expect(refreshed == nil)
        #expect(await barcodeService.callCount == 0)
    }

    @Test func matvaretabellenUpgradeUsesGramBasisForFormerVolumeProduct() {
        let original = Product(
            name: "Flytende testvare",
            barcodeEan: "1234567890123",
            source: "openfoodfacts",
            caloriesPer100g: 80.5,
            proteinGPer100g: 1,
            carbsGPer100g: 10,
            fatGPer100g: 2,
            nutritionSource: .openFoodFacts,
            nutritionBasis: .per100ml
        )
        let mapping = ProductMatchMapping(
            barcode: "1234567890123",
            matvaretabellenId: "42",
            matchedName: "Flytende testvare",
            confidenceScore: 0.9,
            updatedAt: Date(),
            caloriesPer100g: 91.25,
            proteinGPer100g: 2,
            carbsGPer100g: 11,
            fatGPer100g: 3,
            sugarGPer100g: nil,
            fiberGPer100g: nil,
            sodiumMgPer100g: nil,
            category: nil
        )
        let viewModel = makeProductViewModel(
            repository: ProductRepositorySpy(product: original),
            barcodeService: BarcodeServiceSpy(result: .success(original)),
            now: Date()
        )

        let upgraded = viewModel.makeUpgradedProduct(from: original, mapping: mapping, verified: true)

        #expect(upgraded.nutritionBasis == .per100g)
        #expect(upgraded.amountUnit == .grams)
        #expect(upgraded.caloriesPer100g == 91.25)
    }

    @Test func searchFiltersUnrelatedCatalogRowsAndRanksExactProductFirst() {
        let unrelatedNames = [
            "Adzukibønner, tørr",
            "Agavesirup",
            "Agurk, norsk, rå",
            "Aioli"
        ]
        for name in unrelatedNames {
            #expect(!ProductViewModel.searchMatches(query: "Monster Ultra White", name: name))
        }

        let exact = Product(
            name: "Monster Ultra White",
            brand: "Monster",
            source: "openfoodfacts",
            caloriesPer100g: 2,
            proteinGPer100g: 0,
            carbsGPer100g: 0.9,
            fatGPer100g: 0,
            nutritionSource: .openFoodFacts
        )
        let brandMatch = Product(
            name: "Ultra White, Zero Sugar",
            brand: "Monster Energy",
            source: "openfoodfacts",
            caloriesPer100g: 2,
            proteinGPer100g: 0,
            carbsGPer100g: 0.9,
            fatGPer100g: 0,
            nutritionSource: .openFoodFacts
        )

        #expect(ProductViewModel.searchMatches(
            query: "Monster Ultra White",
            name: brandMatch.name,
            brand: brandMatch.brand
        ))
        #expect(ProductViewModel.sortedSearchResults([brandMatch, exact], query: "Monster Ultra White").first?.id == exact.id)
    }

    @Test func openFoodFactsNameSearchReturnsCompletePackagedProducts() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
            let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(components.path == "/cgi/search.pl")
            #expect(queryItems["search_terms"] == "Monster")
            #expect(queryItems["page_size"] == "20")
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("MatLogg/") == true)
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("mailto:") == true)
            #expect(request.timeoutInterval == 10)

            let body = """
            {
              "products": [
                {
                  "code": "5060337502238",
                  "product_name": "Monster Ultra White",
                  "brands": "Monster",
                  "categories": "Energy drinks",
                  "image_front_url": "https://example.test/monster.jpg",
                  "serving_size": "500 ml",
                  "serving_quantity": 500,
                  "product_quantity": 500,
                  "product_quantity_unit": "ml",
                  "nutrition_data_per": "100ml",
                  "nutriments": {
                    "energy-kcal_100g": 2,
                    "proteins_100g": 0,
                    "carbohydrates_100g": 0.9,
                    "fat_100g": 0,
                    "sugars_100g": 0
                  }
                },
                {
                  "code": "incomplete",
                  "product_name": "Incomplete Monster",
                  "nutriments": {
                    "energy-kcal_100g": 3
                  }
                }
              ]
            }
            """
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(
            httpClient: URLSessionHTTPClient(session: URLSession(configuration: configuration)),
            catalogRetryLimit: 0
        )

        let products = try await service.searchProductsByNameOpenFoodFacts("Monster")

        #expect(products.count == 1)
        #expect(products.first?.name == "Monster Ultra White")
        #expect(products.first?.brand == "Monster")
        #expect(products.first?.barcodeEan == "5060337502238")
        #expect(products.first?.imageUrl == "https://example.test/monster.jpg")
        #expect(products.first?.caloriesPer100g == 2)
        #expect(products.first?.carbsGPer100g == 0.9)
        #expect(products.first?.nutritionSource == .openFoodFacts)
        #expect(products.first?.nutritionBasis == .per100ml)
        #expect(products.first?.amountUnit == .milliliters)
        #expect(products.first?.servings?.first?.label == "500 ml")
        #expect(products.first?.servings?.first?.amountUnit == .milliliters)
        #expect(products.first?.servings?.last?.label == "100 ml")
    }

    @Test func openFoodFactsBarcodeDoesNotReplaceMissingMacrosWithZero() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
            let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            #expect(components.path == "/api/v3/product/1234567890123")
            #expect(queryItems["cc"] == "no")
            #expect(queryItems["lc"] == "nb")
            #expect(queryItems["fields"]?.contains("nutriments") == true)
            let body = """
            {
              "status": "success",
              "product": {
                "code": "1234567890123",
                "product_name": "Ufullstendig produkt",
                "nutriments": { "energy-kcal_100g": 120 }
              }
            }
            """
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(
            httpClient: URLSessionHTTPClient(session: URLSession(configuration: configuration))
        )

        do {
            _ = try await service.searchProductByBarcodeOpenFoodFacts("1234567890123")
            Issue.record("Produkt uten komplette makroer skulle ha blitt avvist")
        } catch let error as APIService.APIError {
            guard case .incompleteProductData = error else {
                Issue.record("Forventet incompleteProductData, fikk \(error)")
                return
            }
        }
    }

    @Test func openFoodFactsBarcodeUsesStableIdentityAndPreservesProvenance() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let body = """
            {
              "status": "success",
              "product": {
                "code": "1234567890123",
                "product_name": "Komplett produkt",
                "brands": "Testmerke",
                "nutrition_data_per": "100g",
                "last_modified_t": 1700000000,
                "rev": 12,
                "schema_version": 1003,
                "data_quality_warnings_tags": ["en:test-warning"],
                "nutriments": {
                  "energy-kcal_100g": 120,
                  "proteins_100g": 4,
                  "carbohydrates_100g": 18,
                  "fat_100g": 3
                }
              }
            }
            """
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(
            httpClient: URLSessionHTTPClient(session: URLSession(configuration: configuration))
        )

        let first = try await service.searchProductByBarcodeOpenFoodFacts("1234567890123")
        let second = try await service.searchProductByBarcodeOpenFoodFacts("1234567890123")

        #expect(first.id == second.id)
        #expect(first.id == Product.catalogID(source: "openfoodfacts", externalID: "1234567890123"))
        #expect(first.externalID == "1234567890123")
        #expect(first.nutritionBasis == .per100g)
        #expect(first.sourceRevision == 12)
        #expect(first.sourceSchemaVersion == 1003)
        #expect(first.sourceUpdatedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(first.dataQualityWarnings == ["en:test-warning"])
    }

    @Test func openFoodFactsRateLimitPreservesRetryAfter() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "30"]
            ))
            return (response, Data())
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(
            httpClient: URLSessionHTTPClient(session: URLSession(configuration: configuration)),
            catalogRetryLimit: 0
        )

        do {
            _ = try await service.searchProductsByNameOpenFoodFacts("brød")
            Issue.record("Rate limit skulle ha blitt returnert som feil")
        } catch let error as APIService.APIError {
            guard case .rateLimited(let retryAfterSeconds) = error else {
                Issue.record("Forventet rateLimited, fikk \(error)")
                return
            }
            #expect(retryAfterSeconds == 30)
        }
    }

    @Test func openFoodFactsRetriesServerFailureOnce() async throws {
        var callCount = 0
        SearchURLProtocolStub.handler = { request in
            callCount += 1
            let requestURL = try #require(request.url)
            if callCount == 1 {
                let response = try #require(HTTPURLResponse(
                    url: requestURL,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(#"{"products":[]}"#.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(
            httpClient: URLSessionHTTPClient(session: URLSession(configuration: configuration)),
            catalogRetryLimit: 1,
            sleep: { _ in }
        )

        let products = try await service.searchProductsByNameOpenFoodFacts("brød")

        #expect(products.isEmpty)
        #expect(callCount == 2)
    }
}

private extension ProductSearchTests {
    func makeCachedBarcodeProduct(name: String, fetchedAt: Date?) -> Product {
        Product(
            id: Product.catalogID(source: "openfoodfacts", externalID: "1234567890123"),
            name: name,
            barcodeEan: "1234567890123",
            source: "openfoodfacts",
            caloriesPer100g: 100,
            proteinGPer100g: 4,
            carbsGPer100g: 18,
            fatGPer100g: 3,
            nutritionSource: .openFoodFacts,
            imageSource: .none,
            externalID: "1234567890123",
            nutritionBasis: .per100g,
            fetchedAt: fetchedAt
        )
    }

    func makeProductViewModel(
        repository: ProductRepositorySpy,
        barcodeService: BarcodeServiceSpy,
        now: Date
    ) -> ProductViewModel {
        ProductViewModel(
            repository: repository,
            catalogService: ProductCatalogServiceStub(),
            barcodeService: barcodeService,
            nameSearchService: ProductNameSearchServiceStub(),
            cachePolicy: .standard,
            now: { now }
        )
    }
}

private enum TestBarcodeError: Error {
    case offline
}

private final class BarcodeServiceSpy: BarcodeProductService {
    private(set) var callCount = 0
    private let result: Result<Product, Error>
    private let delayNanoseconds: UInt64

    init(result: Result<Product, Error>, delayNanoseconds: UInt64 = 0) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func searchProductByBarcodeOpenFoodFacts(_ ean: String) async throws -> Product {
        callCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

private struct ProductCatalogServiceStub: ProductCatalogService {
    func fetchCommonFoods() async throws -> [MatvaretabellenProduct] { [] }
    func searchProducts(query: String) async throws -> [MatvaretabellenProduct] { [] }
}

private struct ProductNameSearchServiceStub: ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope) async throws -> [Product] { [] }
}

private final class ProductRepositorySpy: ProductRepository {
    private var product: Product?
    private(set) var cachedProducts: [Product] = []
    var cacheError: Error?

    init(product: Product?) {
        self.product = product
    }

    func saveProduct(_ product: Product, ownerUserId: UUID) async throws { self.product = product }

    func cacheCatalogProduct(_ product: Product) async throws {
        if let cacheError { throw cacheError }
        self.product = product
        cachedProducts.append(product)
    }

    func getSearchableProducts(ownerUserId: UUID?) async throws -> [Product] { product.map { [$0] } ?? [] }

    func getProduct(_ id: UUID) -> Product? { product?.id == id ? product : nil }

    func getProductByBarcode(_ barcode: String, ownerUserId: UUID?) -> Product? {
        product?.barcodeEan == barcode ? product : nil
    }

    func saveMatchMapping(_ mapping: ProductMatchMapping) {}
    func getMatchMapping(for barcode: String) -> ProductMatchMapping? { nil }
    func toggleFavorite(userId: UUID, productId: UUID) async throws {}
    func isFavorite(userId: UUID, productId: UUID) -> Bool { false }
    func saveScanHistory(userId: UUID, productId: UUID) async throws {}
    func getRecentScans(userId: UUID, limit: Int) async -> [ScanHistory] { [] }
    func getFavorites(userId: UUID, kind: ProductKind?) async -> [Product] { [] }
    func getRecentProducts(userId: UUID, kind: ProductKind?, limit: Int) async -> [Product] { [] }
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) {}
    func getMatvaretabellenCache(maxAgeDays: Int) -> [MatvaretabellenProduct]? { nil }
}

private final class SearchURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = Self.handler ?? { _ in throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
