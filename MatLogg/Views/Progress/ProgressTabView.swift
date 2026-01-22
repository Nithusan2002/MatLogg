import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var entries: [WeightEntry] = []
    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: WeightEntry?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Loggfør vekt")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                            
                            DatePicker("Dato", selection: $selectedDate, displayedComponents: .date)
                            
                            TextField("Vekt (kg)", text: $weightText)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(AppColors.surface)
                                .cornerRadius(8)
                            
                            PrimaryButton(title: "Lagre", systemImage: "plus") {
                                Task { await saveWeight() }
                            }
                        }
                    }
                    
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fremgang")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                            
                            #if canImport(Charts)
                            if entries.isEmpty {
                                Text("Ingen vektdata ennå")
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Chart(entries) { entry in
                                    LineMark(
                                        x: .value("Dato", entry.date),
                                        y: .value("Vekt", entry.weightKg)
                                    )
                                    .foregroundStyle(AppColors.brand)
                                    PointMark(
                                        x: .value("Dato", entry.date),
                                        y: .value("Vekt", entry.weightKg)
                                    )
                                    .foregroundStyle(AppColors.brand)
                                }
                                .chartYScale(domain: weightDomain())
                                .frame(height: 220)
                            }
                            #else
                            Text("Graf er ikke tilgjengelig på denne versjonen.")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                            #endif
                        }
                    }
                    
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Historikk")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                            
                            if entries.isEmpty {
                                Text("Ingen vektdata ennå")
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                ForEach(entries.reversed()) { entry in
                                    HStack {
                                        Text(dateLabel(entry.date))
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.ink)
                                        Spacer()
                                        Text("\(formatWeight(entry.weightKg)) kg")
                                            .font(AppTypography.bodyEmphasis)
                                            .foregroundColor(AppColors.ink)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        entryToDelete = entry
                                        showDeleteConfirm = true
                                    }
                                    
                                    Divider().overlay(AppColors.separator)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Fremgang")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.brand)
                }
            }
            .task {
                await reload()
            }
            .alert("Slette vektregistrering?", isPresented: $showDeleteConfirm) {
                Button("Slett", role: .destructive) {
                    if let entryToDelete {
                        Task {
                            await appState.deleteWeightEntry(entryToDelete)
                            await reload()
                        }
                    }
                }
                Button("Avbryt", role: .cancel) {}
            }
        }
    }
    
    private func saveWeight() async {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(normalized), weight > 0 else { return }
        await appState.saveWeightEntry(date: selectedDate, weightKg: weight)
        weightText = ""
        await reload()
    }
    
    private func reload() async {
        entries = await appState.loadWeightEntries()
    }
    
    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: date)
    }
    
    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
    
    #if canImport(Charts)
    private func weightDomain() -> ClosedRange<Double> {
        let values = entries.map { $0.weightKg }
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...1 }
        let padding = max(1.0, (maxVal - minVal) * 0.2)
        return (minVal - padding)...(maxVal + padding)
    }
    #endif
}
