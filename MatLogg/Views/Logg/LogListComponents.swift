import SwiftUI

struct LogRowView: View {
    let log: FoodLog
    let productName: String
    let showCalories: Bool
    let onEdit: (() -> Void)?
    let onMove: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        CardContainer {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(productName)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    
                    Text("\(Int(log.amountG)) \(log.resolvedAmountUnit.rawValue)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if showCalories {
                    Text("\(log.calories) kcal")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Slett", systemImage: "trash")
                }
            }
            if let onMove {
                Button {
                    onMove()
                } label: {
                    Label("Flytt", systemImage: "arrow.left.arrow.right")
                }
                .tint(AppColors.textSecondary)
            }
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Rediger", systemImage: "pencil")
                }
                .tint(AppColors.brand)
            }
        }
    }
}

struct CompactLogListView: View {
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let summary: DailySummary
    let productNames: [UUID: String]
    let maxPerMeal: Int
    let onSeeAll: (String?) -> Void
    
    var body: some View {
        let groups = LogSummaryService.groupedLogs(
            logs: summary.logs,
            productNameLookup: { productNames[$0] ?? "" }
        )
        
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.mealType) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(LogSummaryService.title(for: group.mealType))
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        if group.logs.count > maxPerMeal {
                            Button("Se alt") {
                                onSeeAll(group.mealType)
                            }
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.brand)
                        }
                    }
                    
                    ForEach(LogSummaryService.limitedLogs(group.logs, limit: maxPerMeal)) { log in
                        LogRowView(
                            log: log,
                            productName: productNames[log.productId] ?? "Ukjent produkt",
                            showCalories: !preferencesViewModel.safeModeHideCalories,
                            onEdit: nil,
                            onMove: nil,
                            onDelete: nil
                        )
                    }
                }
            }
            
            Button("Se alt for dagen") {
                onSeeAll(nil)
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(AppColors.brand)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}
