import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var authState: AuthState = .notAuthenticated
    @Published var currentUser: User?
    @Published var currentGoal: Goal?
    @Published var selectedMealType: String = "lunch" // default meal
    @Published var selectedTab: Int = 0
    @Published var todaysSummary: DailySummary?
    @Published var hapticsFeedbackEnabled: Bool = true
    @Published var soundFeedbackEnabled: Bool = true
    @Published var isOnboarding: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let authService = AuthService()
    private let databaseService = DatabaseService()
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        setupBindings()
        checkExistingSession()
    }
    
    private func setupBindings() {
        // Any reactive setup needed
    }
    
    // MARK: - Auth Methods
    
    func checkExistingSession() {
        // Check if user already logged in (from Keychain)
        if let savedUser = authService.getStoredUser(),
           let _ = authService.getStoredToken() {
            self.currentUser = savedUser
            self.authState = .authenticated(user: savedUser)
            loadTodaysGoal()
            loadTodaysSummary()
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
            loadTodaysSummary()
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
        UserDefaults.standard.set(haptics, forKey: "hapticsFeedbackEnabled")
        UserDefaults.standard.set(sound, forKey: "soundFeedbackEnabled")
    }
    
    func loadFeedbackSettings() {
        let defaults = UserDefaults.standard
        hapticsFeedbackEnabled = defaults.bool(forKey: "hapticsFeedbackEnabled")
        soundFeedbackEnabled = defaults.bool(forKey: "soundFeedbackEnabled")
    }
}
