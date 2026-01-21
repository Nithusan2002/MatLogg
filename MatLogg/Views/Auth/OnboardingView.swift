import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var goalType = "maintain"
    @State private var dailyCalories: Double = 2000
    @State private var proteinPercent: Double = 30
    @State private var carbsPercent: Double = 45
    @State private var fatPercent: Double = 25
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                HStack {
                    Text("Onboarding")
                        .font(.title2.bold())
                    Spacer()
                    Text("Steg \(currentStep + 1) av 3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(currentStep + 1), total: 3)
                    .tint(.blue)
                
                Spacer()
                
                if currentStep == 0 {
                    goalTypeStep
                } else if currentStep == 1 {
                    calorieStep
                } else {
                    macroStep
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button("Tilbake") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    
                    Button(action: nextAction) {
                        if appState.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(currentStep == 2 ? "Ferdig" : "Neste")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(appState.isLoading)
                }
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(true)
    }
    
    var goalTypeStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Hva er ditt mål?")
                    .font(.headline)
                Text("Velg måltype for å få personlig tilpassede anbefalinger")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                goalButton(
                    title: "Vekttap",
                    icon: "arrow.down",
                    description: "Jeg vil gå ned i vekt",
                    isSelected: goalType == "weight_loss"
                ) {
                    goalType = "weight_loss"
                    dailyCalories = 1800
                }
                
                goalButton(
                    title: "Opprettholde",
                    icon: "equal",
                    description: "Jeg vil holde min nåværende vekt",
                    isSelected: goalType == "maintain"
                ) {
                    goalType = "maintain"
                    dailyCalories = 2000
                }
                
                goalButton(
                    title: "Muskler",
                    icon: "arrow.up",
                    description: "Jeg vil bygge muskler",
                    isSelected: goalType == "gain"
                ) {
                    goalType = "gain"
                    dailyCalories = 2500
                }
            }
        }
    }
    
    var calorieStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Daglig kalorimål")
                    .font(.headline)
                Text("Hvor mange kalorier ønsker du å spise per dag?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("\(Int(dailyCalories)) kcal")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                Slider(value: $dailyCalories, in: 1000...5000, step: 50)
                    .tint(.blue)
                
                HStack {
                    Text("1000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("5000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                HStack {
                    Text("Ditt mål:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(dailyCalories)) kcal/dag")
                        .fontWeight(.semibold)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    var macroStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Makronæringsstoff")
                    .font(.headline)
                Text("Velg deling av protein, karbo og fett")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                macroSlider(
                    label: "Protein",
                    value: $proteinPercent,
                    color: .red,
                    unit: "%"
                )
                
                macroSlider(
                    label: "Karbohydrater",
                    value: $carbsPercent,
                    color: .orange,
                    unit: "%"
                )
                
                macroSlider(
                    label: "Fett",
                    value: $fatPercent,
                    color: .yellow,
                    unit: "%"
                )
                
                HStack {
                    Text("Total:")
                    Spacer()
                    Text("\(Int(proteinPercent + carbsPercent + fatPercent))%")
                        .fontWeight(.semibold)
                        .foregroundColor(proteinPercent + carbsPercent + fatPercent == 100 ? .green : .red)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    func goalButton(title: String, icon: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    func macroSlider(label: String, value: Binding<Double>, color: Color, unit: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            Slider(value: value, in: 0...100, step: 1)
                .tint(color)
        }
    }
    
    private func nextAction() {
        if currentStep < 2 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        Task {
            let proteinG = Float(dailyCalories) * Float(proteinPercent) / 100 / 4
            let carbsG = Float(dailyCalories) * Float(carbsPercent) / 100 / 4
            let fatG = Float(dailyCalories) * Float(fatPercent) / 100 / 9
            
            await appState.completeOnboarding(
                goalType: goalType,
                dailyCalories: Int(dailyCalories),
                proteinTarget: proteinG,
                carbsTarget: carbsG,
                fatTarget: fatG
            )
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
            .environmentObject(AppState())
    }
}
