import SwiftUI

/// Fixed export canvas; the surrounding controls, rather than this image, follow Dynamic Type.
struct MealShareCardView: View {
    let snapshot: MealShareSnapshot
    let style: MealShareStyle
    let photo: UIImage?
    var content = MealShareContent()
    private var isLight: Bool { style == .light }
    private var foreground: Color { isLight ? AppColors.deepInk : AppColors.surface }

    var body: some View {
        ZStack {
            (isLight ? AppColors.background : AppColors.deepInk)
            if style == .photo {
                photoCard
            } else {
                standardCard
            }
        }
        .foregroundStyle(foreground)
        .frame(width: 360, height: 640)
        .clipped()
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            wordmark
            mealTitle
            if let photo {
                // Let the image absorb the available height, leaving room for long names and all values.
                GeometryReader { geometry in
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .layoutPriority(-1)
            } else {
                Spacer(minLength: 24)
            }
            if content.hasNutrition { nutrition }
        }
        .padding(24)
    }

    private var photoCard: some View {
        ZStack(alignment: .topLeading) {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: 360, height: 640).clipped()
            }
            wordmark
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    if photo != nil {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.deepInk.opacity(0.8))
                    }
                }
                .padding(24)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 16) {
                    mealTitle
                    if content.hasNutrition { nutrition }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 72)
                .background {
                    // The scrim follows the text group's height; the photo above stays unobscured.
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: AppColors.deepInk.opacity(0.72), location: 0.22),
                        .init(color: AppColors.deepInk.opacity(0.95), location: 0.65),
                        .init(color: AppColors.deepInk, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
        }
    }

    private var wordmark: some View {
        Text("MatLogg").font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(isLight ? AppColors.brand : foreground)
    }

    private var mealTitle: some View {
        Text(snapshot.name).font(.system(size: 30, weight: .bold, design: .rounded))
            .lineLimit(3).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nutrition: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hele måltidet").font(.system(size: 16, weight: .medium))
                if content.calories {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(number(snapshot.nutrition.calories, decimals: 0))
                            .font(.system(size: 50, weight: .bold, design: .rounded))
                        Text("kcal").font(.system(size: 27, weight: .medium))
                    }.minimumScaleFactor(0.5).lineLimit(1)
                }
            }
            if content.hasMacros {
                HStack(spacing: 8) {
                    if content.protein { macro(snapshot.nutrition.protein, title: "Protein", tint: AppColors.macroProteinTint) }
                    if content.carbs { macro(snapshot.nutrition.carbs, title: "Karbohydrater", tint: AppColors.macroCarbTint) }
                    if content.fat { macro(snapshot.nutrition.fat, title: "Fett", tint: AppColors.macroFatTint) }
                }
            }
        }
    }

    private func macro(_ value: Float, title: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            if !isLight { Capsule().fill(tint).frame(width: 24, height: 4) }
            Text(number(value, decimals: 1) + " g").font(.system(size: 24, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isLight ? tint.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 16))
    }

    private func number(_ value: Float, decimals: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "nb_NO")).precision(.fractionLength(decimals)))
    }
}
