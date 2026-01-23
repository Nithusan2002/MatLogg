import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var authState: AuthState = .notAuthenticated
    @Published var currentUser: User?
    @Published var currentGoal: Goal? = Goal(
        userId: UUID(),
        goalType: "maintain",
        dailyCalories: 2000,
        proteinTargetG: 150,
        carbsTargetG: 250,
        fatTargetG: 65,
        intent: .maintain,
        pace: .calm,
        activityLevel: .moderat,
        safeModeEnabled: false
    )
    @Published var selectedMealType: String = "lunsj" // default meal
    @Published var selectedTab: Int = 0
    @Published var logSelectedDate: Date = Date()
    @Published var logSelectedMeal: String?
    @Published var todaysSummary: DailySummary? = DailySummary(date: Date(), totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, logs: [])
    @Published var hapticsFeedbackEnabled: Bool = true { didSet { storeBool(hapticsFeedbackEnabled, key: "hapticsFeedbackEnabled") } }
    @Published var soundFeedbackEnabled: Bool = true { didSet { storeBool(soundFeedbackEnabled, key: "soundFeedbackEnabled") } }
    @Published var showGoalStatusOnHome: Bool = true { didSet { storeBool(showGoalStatusOnHome, key: "showGoalStatusOnHome") } }
    @Published var safeModeEnabled: Bool = false {
        didSet {
            storeBool(safeModeEnabled, key: "safeModeEnabled")
            if safeModeEnabled {
                safeModeHideCalories = true
                safeModeHideGoals = true
            }
        }
    }
    @Published var safeModeHideCalories: Bool = false { didSet { storeBool(safeModeHideCalories, key: "safeModeHideCalories") } }
    @Published var safeModeHideGoals: Bool = false { didSet { storeBool(safeModeHideGoals, key: "safeModeHideGoals") } }
    @Published var showNutritionSource: Bool = true { didSet { storeBool(showNutritionSource, key: "showNutritionSource") } }
    @Published var analyticsEnabled: Bool = false {
        didSet {
            storeBool(analyticsEnabled, key: "analyticsEnabled")
            AnalyticsManager.shared.setEnabled(analyticsEnabled)
        }
    }
    @Published var crashReportsEnabled: Bool = false {
        didSet {
            storeBool(crashReportsEnabled, key: "crashReportsEnabled")
            CrashReportingManager.shared.setEnabled(crashReportsEnabled)
        }
    }
    @Published var hasSeenPrivacyChoices: Bool = false { didSet { storeBool(hasSeenPrivacyChoices, key: "hasSeenPrivacyChoices") } }
    @Published var personalDetails: PersonalDetails = .empty { didSet { storePersonalDetails() } }
    @Published var isOnboarding: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let authService = AuthService()
    private let databaseService = DatabaseService()
    private let apiService = APIService()
    private let matvaretabellenService = MatvaretabellenService()
    private let matchingService = MatchingService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        setupBindings()
        loadPreferences()
        checkExistingSession()
    }
    
    private func setupBindings() {
        // Any reactive setup needed
    }
    
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        hapticsFeedbackEnabled = defaults.object(forKey: "hapticsFeedbackEnabled") as? Bool ?? true
        soundFeedbackEnabled = defaults.object(forKey: "soundFeedbackEnabled") as? Bool ?? true
        showGoalStatusOnHome = defaults.object(forKey: "showGoalStatusOnHome") as? Bool ?? true
        safeModeEnabled = defaults.object(forKey: "safeModeEnabled") as? Bool ?? false
        safeModeHideCalories = defaults.object(forKey: "safeModeHideCalories") as? Bool ?? false
        safeModeHideGoals = defaults.object(forKey: "safeModeHideGoals") as? Bool ?? false
        showNutritionSource = defaults.object(forKey: "showNutritionSource") as? Bool ?? true
        analyticsEnabled = defaults.object(forKey: "analyticsEnabled") as? Bool ?? false
        crashReportsEnabled = defaults.object(forKey: "crashReportsEnabled") as? Bool ?? false
        hasSeenPrivacyChoices = defaults.object(forKey: "hasSeenPrivacyChoices") as? Bool ?? false
        if let data = defaults.data(forKey: "personalDetails"),
           let decoded = try? JSONDecoder().decode(PersonalDetails.self, from: data) {
            personalDetails = decoded
        }
        AnalyticsManager.shared.setEnabled(analyticsEnabled)
        CrashReportingManager.shared.setEnabled(crashReportsEnabled)
    }
    
    private func storeBool(_ value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func storePersonalDetails() {
        if let data = try? JSONEncoder().encode(personalDetails) {
            UserDefaults.standard.set(data, forKey: "personalDetails")
        }
    }
    
    // MARK: - Auth Methods
    
    func checkExistingSession() {
        // Check if user already logged in (from Keychain)
        if let savedUser = authService.getStoredUser(),
           let _ = authService.getStoredToken() {
            self.currentUser = savedUser
            self.authState = .authenticated(user: savedUser)
            loadTodaysGoal()
            // loadTodaysSummary is async, will be called from UI onAppear
        }
    }
    
    func loginWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (user, token) = try await apiService.loginEmail(email: email, password: password)
            authService.storeUser(user)
            authService.storeToken(token)
            self.currentUser = user
            self.authState = .authenticated(user: user)
            loadTodaysGoal()
            await loadTodaysSummary()
        } catch {
            self.errorMessage = error.localizedDescription
            self.authState = .error(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func signupWithEmail(email: String, password: String, firstName: String, lastName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (user, token) = try await apiService.signupEmail(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            authService.storeUser(user)
            authService.storeToken(token)
            self.currentUser = user
            self.authState = .onboarding(user: user)
            self.isOnboarding = true
        } catch {
            self.errorMessage = error.localizedDescription
            self.authState = .error(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func completeOnboarding(
        goalType: String,
        dailyCalories: Int,
        proteinTarget: Float,
        carbsTarget: Float,
        fatTarget: Float
    ) async {
        guard let user = currentUser else { return }
        
        isLoading = true
        
        let goal = Goal(
            userId: user.id,
            goalType: goalType,
            dailyCalories: dailyCalories,
            proteinTargetG: proteinTarget,
            carbsTargetG: carbsTarget,
            fatTargetG: fatTarget
        )
        
        do {
            try await databaseService.saveGoal(goal)
            self.currentGoal = goal
            self.authState = .authenticated(user: user)
            self.isOnboarding = false
        } catch {
            self.errorMessage = "Kunne ikke lagre mål: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func logout() {
        authService.clearStoredCredentials()
        self.currentUser = nil
        self.currentGoal = nil
        self.authState = .notAuthenticated
    }

    func deleteAccount() async {
        // TODO: Call backend delete when available.
        logout()
    }
    
    // MARK: - Logging Methods
    
    func logFood(product: Product, amountG: Float, mealType: String, date: Date = Date()) async {
        guard let user = currentUser else { return }
        
        let nutrition = product.calculateNutrition(forGrams: amountG)
        let log = FoodLog(
            userId: user.id,
            productId: product.id,
            mealType: mealType,
            amountG: amountG,
            loggedDate: Calendar.current.startOfDay(for: date),
            loggedTime: date,
            calories: nutrition.calories,
            proteinG: nutrition.protein,
            carbsG: nutrition.carbs,
            fatG: nutrition.fat
        )
        
        do {
            try await databaseService.saveLog(log)
            await loadTodaysSummary()
        } catch {
            self.errorMessage = "Kunne ikke lagre logging: \(error.localizedDescription)"
        }
    }
    
    func deleteLog(_ log: FoodLog) async {
        do {
            try await databaseService.deleteLog(log.id)
            await loadTodaysSummary()
        } catch {
            self.errorMessage = "Kunne ikke slette logging: \(error.localizedDescription)"
        }
    }
    
    func undoLatestLog(productId: UUID, mealType: String, amountG: Float, date: Date = Date()) async {
        guard let user = currentUser else { return }
        let logs = await databaseService.getAllLogs(userId: user.id)
        let day = Calendar.current.startOfDay(for: date)
        let candidates = logs.filter {
            $0.productId == productId &&
            $0.mealType == mealType &&
            $0.amountG == amountG &&
            Calendar.current.isDate($0.loggedDate, inSameDayAs: day)
        }
        guard let latest = candidates.max(by: { $0.loggedTime < $1.loggedTime }) else { return }
        
        do {
            try await databaseService.deleteLog(latest.id)
            await loadTodaysSummary()
        } catch {
            self.errorMessage = "Kunne ikke angre logging: \(error.localizedDescription)"
        }
    }
    
    func updateLog(_ log: FoodLog, amountG: Float, mealType: String) async {
        guard let product = getProduct(log.productId) else { return }
        let nutrition = product.calculateNutrition(forGrams: amountG)
        let updated = FoodLog(
            id: log.id,
            userId: log.userId,
            productId: log.productId,
            mealType: mealType,
            amountG: amountG,
            loggedDate: log.loggedDate,
            loggedTime: log.loggedTime,
            calories: nutrition.calories,
            proteinG: nutrition.protein,
            carbsG: nutrition.carbs,
            fatG: nutrition.fat,
            createdAt: log.createdAt,
            isSynced: log.isSynced
        )
        
        do {
            try await databaseService.saveLog(updated)
            await loadTodaysSummary()
        } catch {
            self.errorMessage = "Kunne ikke oppdatere logging: \(error.localizedDescription)"
        }
    }

    func copyLogs(from sourceDate: Date, to targetDate: Date) async {
        guard let user = currentUser else { return }
        
        let sourceSummary = await databaseService.getSummary(userId: user.id, date: sourceDate)
        let targetDay = Calendar.current.startOfDay(for: targetDate)
        
        do {
            for log in sourceSummary.logs {
                let newLog = FoodLog(
                    userId: user.id,
                    productId: log.productId,
                    mealType: log.mealType,
                    amountG: log.amountG,
                    loggedDate: targetDay,
                    loggedTime: Date(),
                    calories: log.calories,
                    proteinG: log.proteinG,
                    carbsG: log.carbsG,
                    fatG: log.fatG
                )
                try await databaseService.saveLog(newLog)
            }
            await loadTodaysSummary()
        } catch {
            self.errorMessage = "Kunne ikke kopiere logging: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Data Loading
    
    func loadTodaysGoal() {
        guard let user = currentUser else { return }
        
        databaseService.getLatestGoal(userId: user.id) { [weak self] goal in
            DispatchQueue.main.async {
                self?.currentGoal = goal
            }
        }
    }
    
    func loadTodaysSummary() async {
        guard let user = currentUser else { return }
        
        let summary = await databaseService.getTodaysSummary(userId: user.id)
        DispatchQueue.main.async {
            self.todaysSummary = summary
        }
    }

    func fetchSummary(for date: Date) async -> DailySummary? {
        guard let user = currentUser else { return nil }
        return await databaseService.getSummary(userId: user.id, date: date)
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(product: Product) async {
        guard let user = currentUser else { return }
        
        do {
            try await databaseService.toggleFavorite(userId: user.id, productId: product.id)
        } catch {
            self.errorMessage = "Kunne ikke oppdatere favoritt: \(error.localizedDescription)"
        }
    }
    
    func isFavorite(_ product: Product) -> Bool {
        guard let user = currentUser else { return false }
        return databaseService.isFavorite(userId: user.id, productId: product.id)
    }
    
    // MARK: - Settings
    
    func updateFeedbackSettings(haptics: Bool, sound: Bool) {
        hapticsFeedbackEnabled = haptics
        soundFeedbackEnabled = sound
    }
    
    func loadFeedbackSettings() {
        loadPreferences()
    }

    // MARK: - Product Amount Memory

    func getLastUsedAmount(for productId: UUID) -> Double? {
        let key = lastAmountKey(for: productId)
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : nil
    }

    func setLastUsedAmount(_ amount: Double, for productId: UUID) {
        let key = lastAmountKey(for: productId)
        UserDefaults.standard.set(amount, forKey: key)
    }

    func shouldUseLastAmount(for productId: UUID) -> Bool {
        let key = useLastAmountKey(for: productId)
        return UserDefaults.standard.bool(forKey: key)
    }

    func setUseLastAmount(_ enabled: Bool, for productId: UUID) {
        let key = useLastAmountKey(for: productId)
        UserDefaults.standard.set(enabled, forKey: key)
    }
    
    func enableDebugSession() {
        if currentUser == nil {
            let user = User(
                id: UUID(),
                email: "dev@matlogg.app",
                firstName: "Dev",
                lastName: "User",
                authProvider: "debug",
                createdAt: Date()
            )
            currentUser = user
            authState = .authenticated(user: user)
            isOnboarding = false
            
            if currentGoal == nil || currentGoal?.userId != user.id {
                currentGoal = Goal(
                    userId: user.id,
                    goalType: "maintain",
                    dailyCalories: 2000,
                    proteinTargetG: 150,
                    carbsTargetG: 250,
                    fatTargetG: 65,
                    intent: .maintain,
                    pace: .calm,
                    activityLevel: .moderat,
                    safeModeEnabled: safeModeEnabled
                )
            }
        }
    }
    
    func saveScannedProduct(_ product: Product) async {
        guard let user = currentUser else { return }
        
        do {
            try await databaseService.saveProduct(product)
            try await databaseService.saveScanHistory(userId: user.id, productId: product.id)
        } catch {
            self.errorMessage = "Kunne ikke lagre skanning: \(error.localizedDescription)"
        }
    }
    
    func loadRecentScans(limit: Int = 15) async -> [ScanHistory] {
        guard let user = currentUser else { return [] }
        return await databaseService.getRecentScans(userId: user.id, limit: limit)
    }
    
    func getProduct(_ id: UUID) -> Product? {
        databaseService.getProduct(id)
    }
    
    func getProductByBarcode(_ barcode: String) -> Product? {
        databaseService.getProductByBarcode(barcode)
    }

    func loadRecentProducts(kind: ProductKind? = nil, limit: Int = 10) async -> [Product] {
        guard let user = currentUser else { return [] }
        return await databaseService.getRecentProducts(userId: user.id, kind: kind, limit: limit)
    }
    
    func loadFavoriteProducts(kind: ProductKind? = nil) async -> [Product] {
        guard let user = currentUser else { return [] }
        return await databaseService.getFavorites(userId: user.id, kind: kind)
    }
    
    func loadRawFoodSuggestions() async -> [MatvaretabellenProduct] {
        if let cached = databaseService.getMatvaretabellenCache(maxAgeDays: 30) {
            return cached
        }
        let items = (try? await matvaretabellenService.fetchCommonFoods()) ?? []
        databaseService.saveMatvaretabellenCache(items)
        return items
    }
    
    func searchRawFoods(query: String) async -> [MatvaretabellenProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        if let cached = databaseService.getMatvaretabellenCache(maxAgeDays: 30), !cached.isEmpty {
            let filtered = cached.filter { normalize($0.name).contains(normalize(trimmed)) }
            if !filtered.isEmpty {
                return filtered
            }
        }
        
        let items = (try? await matvaretabellenService.searchProducts(query: trimmed)) ?? []
        if items.isEmpty, let cached = databaseService.getMatvaretabellenCache(maxAgeDays: 30) {
            return cached.filter { normalize($0.name).contains(normalize(trimmed)) }
        }
        return items
    }

    func upgradeNutritionIfPossible(for product: Product) async -> Product? {
        guard let barcode = product.barcodeEan else { return nil }
        
        if let mapping = databaseService.getMatchMapping(for: barcode) {
            let daysOld = Calendar.current.dateComponents([.day], from: mapping.updatedAt, to: Date()).day ?? 0
            if daysOld <= 30, mapping.confidenceScore >= 0.85 {
                let upgraded = Product(
                    id: product.id,
                    name: product.name,
                    brand: product.brand,
                    category: mapping.category ?? product.category,
                    barcodeEan: barcode,
                    source: product.source,
                    kind: product.kind,
                    caloriesPer100g: mapping.caloriesPer100g,
                    proteinGPer100g: mapping.proteinGPer100g,
                    carbsGPer100g: mapping.carbsGPer100g,
                    fatGPer100g: mapping.fatGPer100g,
                    sugarGPer100g: mapping.sugarGPer100g,
                    fiberGPer100g: mapping.fiberGPer100g,
                    sodiumMgPer100g: mapping.sodiumMgPer100g,
                    imageUrl: product.imageUrl,
                    standardPortions: product.standardPortions,
                    servings: product.servings,
                    nutritionSource: .matvaretabellen,
                    imageSource: product.imageUrl == nil ? .none : product.imageSource,
                    verificationStatus: .verified,
                    confidenceScore: mapping.confidenceScore,
                    isVerified: true,
                    createdAt: product.createdAt
                )
                try? await databaseService.saveProduct(upgraded)
                return upgraded
            }
        }
        
        let candidates = (try? await matvaretabellenService.searchProducts(query: product.name)) ?? []
        guard let best = matchingService.bestMatch(offProduct: product, candidates: candidates) else {
            return nil
        }
        
        if best.score >= 0.85 {
            let mapping = ProductMatchMapping(
                barcode: barcode,
                matvaretabellenId: best.product.id,
                matchedName: best.product.name,
                confidenceScore: best.score,
                updatedAt: Date(),
                caloriesPer100g: best.product.caloriesPer100g,
                proteinGPer100g: best.product.proteinGPer100g,
                carbsGPer100g: best.product.carbsGPer100g,
                fatGPer100g: best.product.fatGPer100g,
                sugarGPer100g: best.product.sugarGPer100g,
                fiberGPer100g: best.product.fiberGPer100g,
                sodiumMgPer100g: best.product.sodiumMgPer100g,
                category: best.product.category
            )
            databaseService.saveMatchMapping(mapping)
            
            let upgraded = Product(
                id: product.id,
                name: product.name,
                brand: product.brand,
                category: best.product.category ?? product.category,
                barcodeEan: barcode,
                source: product.source,
                kind: product.kind,
                caloriesPer100g: best.product.caloriesPer100g,
                proteinGPer100g: best.product.proteinGPer100g,
                carbsGPer100g: best.product.carbsGPer100g,
                fatGPer100g: best.product.fatGPer100g,
                sugarGPer100g: best.product.sugarGPer100g,
                fiberGPer100g: best.product.fiberGPer100g,
                sodiumMgPer100g: best.product.sodiumMgPer100g,
                imageUrl: product.imageUrl,
                standardPortions: product.standardPortions,
                servings: product.servings,
                nutritionSource: .matvaretabellen,
                imageSource: product.imageUrl == nil ? .none : product.imageSource,
                verificationStatus: .verified,
                confidenceScore: best.score,
                isVerified: true,
                createdAt: product.createdAt
            )
            try? await databaseService.saveProduct(upgraded)
            return upgraded
        }
        
        if best.score >= 0.60 {
            let mapping = ProductMatchMapping(
                barcode: barcode,
                matvaretabellenId: best.product.id,
                matchedName: best.product.name,
                confidenceScore: best.score,
                updatedAt: Date(),
                caloriesPer100g: best.product.caloriesPer100g,
                proteinGPer100g: best.product.proteinGPer100g,
                carbsGPer100g: best.product.carbsGPer100g,
                fatGPer100g: best.product.fatGPer100g,
                sugarGPer100g: best.product.sugarGPer100g,
                fiberGPer100g: best.product.fiberGPer100g,
                sodiumMgPer100g: best.product.sodiumMgPer100g,
                category: best.product.category
            )
            databaseService.saveMatchMapping(mapping)
            
            let suggested = Product(
                id: product.id,
                name: product.name,
                brand: product.brand,
                category: product.category,
                barcodeEan: barcode,
                source: product.source,
                kind: product.kind,
                caloriesPer100g: product.caloriesPer100g,
                proteinGPer100g: product.proteinGPer100g,
                carbsGPer100g: product.carbsGPer100g,
                fatGPer100g: product.fatGPer100g,
                sugarGPer100g: product.sugarGPer100g,
                fiberGPer100g: product.fiberGPer100g,
                sodiumMgPer100g: product.sodiumMgPer100g,
                imageUrl: product.imageUrl,
                standardPortions: product.standardPortions,
                servings: product.servings,
                nutritionSource: product.nutritionSource,
                imageSource: product.imageUrl == nil ? .none : product.imageSource,
                verificationStatus: .suggestedMatch,
                confidenceScore: best.score,
                isVerified: false,
                createdAt: product.createdAt
            )
            try? await databaseService.saveProduct(suggested)
            return suggested
        }
        
        return nil
    }

    func exportUserData() async -> URL? {
        guard let user = currentUser else { return nil }
        let logs = await databaseService.getAllLogs(userId: user.id)
        let payload: [String: Any] = [
            "user_id": user.id.uuidString,
            "email": user.email,
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "logs": logs.map { log in
                [
                    "product_id": log.productId.uuidString,
                    "meal_type": log.mealType,
                    "amount_g": log.amountG,
                    "logged_date": ISO8601DateFormatter().string(from: log.loggedDate),
                    "calories": log.calories,
                    "protein_g": log.proteinG,
                    "carbs_g": log.carbsG,
                    "fat_g": log.fatG
                ]
            }
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return nil
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("matlogg-export.json")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    // MARK: - Weight Tracking
    
    func saveWeightEntry(date: Date, weightKg: Double) async {
        guard let user = currentUser else { return }
        let entry = WeightEntry(userId: user.id, date: date, weightKg: weightKg)
        do {
            try await databaseService.saveWeightEntry(entry)
        } catch {
            self.errorMessage = "Kunne ikke lagre vekt: \(error.localizedDescription)"
        }
    }
    
    func loadWeightEntries() async -> [WeightEntry] {
        guard let user = currentUser else { return [] }
        return await databaseService.getWeightEntries(userId: user.id)
    }
    
    func deleteWeightEntry(_ entry: WeightEntry) async {
        do {
            try await databaseService.deleteWeightEntry(entry.id)
        } catch {
            self.errorMessage = "Kunne ikke slette vekt: \(error.localizedDescription)"
        }
    }

    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func lastAmountKey(for productId: UUID) -> String {
        let userId = currentUser?.id.uuidString ?? "anonymous"
        return "lastAmount.\(userId).\(productId.uuidString)"
    }

    private func useLastAmountKey(for productId: UUID) -> String {
        let userId = currentUser?.id.uuidString ?? "anonymous"
        return "useLastAmount.\(userId).\(productId.uuidString)"
    }
}
