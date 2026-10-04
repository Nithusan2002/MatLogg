import SwiftUI

struct LogRowView: View {
    let log: FoodLog
    let productName: String
    var compact: Bool = false
    var mealRoom: Bool = false
    var imageURL: URL? = nil
    var imageData: Data? = nil
    let onEdit: (() -> Void)?
    let onMove: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        Group {
            if compact {
                rowContent.padding(.horizontal, 16).padding(.vertical, mealRoom ? 10 : 12)
            } else {
                CardContainer { rowContent }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit?() }
        .accessibilityActions {
            if let onEdit {
                Button("Rediger", action: onEdit)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(mealRoom && onEdit != nil ? .isButton : [])
        .accessibilityHint(mealRoom && onEdit != nil ? "Trykk for å redigere mengde eller flytte varen" : "")
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
    @ViewBuilder
    private var rowContent: some View {
        if mealRoom {
            HStack(alignment: .top, spacing: 12) {
                ProductThumbnailView(url: imageURL, localData: imageData, size: 52, imagePadding: 2)
                VStack(alignment: .leading, spacing: 4) {
                    productDescription
                    Text("\(NutritionDisplay.wholeCalories(log.calories)) kcal · P \(NutritionDisplay.wholeGrams(log.proteinG)) g · K \(NutritionDisplay.wholeGrams(log.carbsG)) g · F \(NutritionDisplay.wholeGrams(log.fatG)) g")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("\(NutritionDisplay.wholeCalories(log.calories)) kilokalorier, protein \(NutritionDisplay.wholeGrams(log.proteinG)) gram, karbohydrat \(NutritionDisplay.wholeGrams(log.carbsG)) gram, fett \(NutritionDisplay.wholeGrams(log.fatG)) gram")

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    productDescription
                    Spacer(minLength: 12)
                    calories
                }
                VStack(alignment: .leading, spacing: 8) {
                    productDescription
                    calories
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var productDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(productName)
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(PortionDisplay.amount(Double(log.amountG), unit: log.resolvedAmountUnit, portion: log.portionSelection))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var calories: some View {
        Text("\(NutritionDisplay.wholeCalories(log.calories)) kcal")
            .font(AppTypography.bodyEmphasis)
            .foregroundStyle(AppColors.ink)
            .fixedSize()
    }
}

struct CompactLogListView: View {
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
                            .foregroundColor(AppColors.actionText)
                        }
                    }
                    
                    ForEach(LogSummaryService.limitedLogs(group.logs, limit: maxPerMeal)) { log in
                        LogRowView(
                            log: log,
                            productName: productNames[log.productId] ?? "Ukjent produkt",
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
            .foregroundColor(AppColors.actionText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}
