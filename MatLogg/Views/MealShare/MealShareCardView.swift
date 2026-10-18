import SwiftUI

/// Fixed export canvas; the surrounding controls, rather than this image, follow Dynamic Type.
struct MealShareCardView: View {
    let snapshot: MealShareSnapshot
    let style: MealShareStyle
    let photo: UIImage?
    private var isLight: Bool { style == .light }
    private var foreground: Color { isLight ? AppColors.deepInk : AppColors.surface }

    var body: some View {
        ZStack {
            (isLight ? AppColors.background : AppColors.deepInk)
            if style == .photo, let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: 360, height: 640).clipped()
                LinearGradient(colors: [AppColors.deepInk.opacity(0.65), .clear],
                               startPoint: .top, endPoint: .center)
                LinearGradient(colors: [.clear, AppColors.deepInk.opacity(0.7), AppColors.deepInk],
                               startPoint: .top, endPoint: .bottom)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("MatLogg").font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isLight ? AppColors.brand : foreground)
                if style == .photo { Spacer(minLength: 40) }
                Text(snapshot.name).font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(3).minimumScaleFactor(0.65).frame(maxWidth: .infinity, alignment: .leading)
                if style != .photo, let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: 312, height: 185).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                } else if style != .photo { Spacer(minLength: 20) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hele måltidet").font(.system(size: 16, weight: .medium))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(number(snapshot.nutrition.calories, decimals: 0)).font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("kcal").font(.system(size: 27, weight: .medium))
                    }.minimumScaleFactor(0.5).lineLimit(1)
                }
                HStack(spacing: 8) {
                    macro(snapshot.nutrition.protein, title: "Protein", tint: AppColors.macroProteinTint)
                    macro(snapshot.nutrition.carbs, title: "Karbohydrater", tint: AppColors.macroCarbTint)
                    macro(snapshot.nutrition.fat, title: "Fett", tint: AppColors.macroFatTint)
                }
                if style != .photo { Spacer(minLength: 0) }
            }.padding(24)
        }
        .foregroundStyle(foreground)
        .frame(width: 360, height: 640)
        .clipped()
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
    }

    private func macro(_ value: Float, title: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            if !isLight { Capsule().fill(tint).frame(width: 24, height: 4) }
            Text(number(value, decimals: 1) + " g").font(.system(size: 21, weight: .bold))
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
