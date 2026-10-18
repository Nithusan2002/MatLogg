import SwiftUI

struct MealShareView: View {
    @ObservedObject var model: MealShareViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCustomizing = false

    var body: some View {
        NavigationStack {
            GeometryReader { available in
                ScrollView {
                    VStack(spacing: 16) {
                        if model.isPreparing { ProgressView("Klargjør kort …") }
                        if let snapshot = model.snapshot {
                            TabView(selection: Binding(get: { model.style }, set: { model.select($0) })) {
                                ForEach(MealShareStyle.allCases) { style in
                                    GeometryReader { geometry in
                                        let width = min(geometry.size.width - 24, (geometry.size.height - 16) * 9 / 16)
                                        MealShareCardView(snapshot: snapshot, style: style, photo: model.photo, content: model.content)
                                            .scaleEffect(width / 360)
                                            .frame(width: width, height: width * 16 / 9)
                                            .overlay(Rectangle().stroke(AppColors.controlBorder.opacity(0.5), lineWidth: 1))
                                            .shadow(color: AppColors.deepInk.opacity(0.12), radius: 6, y: 3)
                                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                    }
                                    .padding(.horizontal, 8)
                                    .tag(style)
                                    .accessibilityLabel("\(style.title) måltidskort")
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .frame(height: dynamicTypeSize.isAccessibilitySize
                                ? min(260, max(160, available.size.height * 0.45))
                                : min(500, max(240, available.size.height - 240)))
                            .disabled(model.isExporting)
                            let layout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                            layout {
                                ForEach(MealShareStyle.allCases) { style in
                                    Button {
                                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { model.select(style) }
                                    } label: {
                                        let contentLayout = dynamicTypeSize.isAccessibilitySize
                                            ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 8))
                                        contentLayout {
                                            MealShareCardView(snapshot: snapshot, style: style, photo: model.photo, content: model.content)
                                                .scaleEffect(0.15)
                                                .frame(width: 54, height: 96)
                                                .accessibilityHidden(true)
                                            Label(style.title, systemImage: model.style == style ? "checkmark.circle.fill" : "circle")
                                                .font(AppTypography.captionEmphasis)
                                                .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                                        }.frame(maxWidth: .infinity, minHeight: 44).padding(12)
                                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.style == style ? AppColors.action : AppColors.separator, lineWidth: 2))
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(style.title)
                                    .accessibilityAddTraits(model.style == style ? .isSelected : [])
                                    .accessibilityIdentifier("meal-share-style-\(style.rawValue)")
                                    .disabled(model.isExporting)
                                }
                            }
                            if model.style == .photo && model.photo == nil {
                                Text("Legg til et måltidsbilde for fotobakgrunn.").font(AppTypography.caption)
                            }
                        }
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    isCustomizing.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Tilpass innhold").font(AppTypography.bodyEmphasis)
                                    Spacer()
                                    Text("\(model.content.selectedCount) av 5")
                                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                                    Image(systemName: isCustomizing ? "chevron.up" : "chevron.down")
                                        .font(AppTypography.captionEmphasis)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(isCustomizing ? "Utvidet" : "Skjult")
                            .accessibilityIdentifier("meal-share-customize")
                            if isCustomizing {
                                VStack(spacing: 12) {
                                    contentToggle("Kalorier", keyPath: \.calories, id: "calories")
                                    contentToggle("Protein", keyPath: \.protein, id: "protein")
                                    contentToggle("Karbohydrater", keyPath: \.carbs, id: "carbs")
                                    contentToggle("Fett", keyPath: \.fat, id: "fat")
                                    contentToggle("MatLogg-logo", keyPath: \.logo, id: "logo")
                                    Text(model.content.hasNutrition
                                         ? "Deler bilde, måltidsnavn og valgte næringsverdier."
                                         : "Deler bilde og måltidsnavn uten næringsverdier.")
                                        .font(AppTypography.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(.top, 12)
                            }
                        }
                        .tint(AppColors.action)
                        .disabled(model.isExporting || model.snapshot == nil)
                        if let warning = model.photoWarning { Text(warning).font(AppTypography.caption) }
                        if let error = model.errorMessage { ErrorMessageView(error) }
                    }.padding(16).padding(.bottom, 24)
                }
                .accessibilityIdentifier("meal-share-scroll")
                .background(AppColors.background)
            }
            .navigationTitle("Del måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Lukk") { dismiss() }.accessibilityIdentifier("meal-share-close") } }
            .safeAreaInset(edge: .bottom, spacing: 12) {
                PrimaryButton(title: model.isExporting ? "Lager kort …" : "Del kortet") {
                    Task { await model.export() }
                }
                .disabled(model.snapshot == nil || model.isPreparing || model.isExporting)
                .accessibilityIdentifier("meal-share-export")
                .padding(16).background(AppColors.background)
            }
        }
        .sheet(item: $model.sharedImage) { item in
            ShareSheet(activityItems: [item.image], onCompletion: { model.sharedImage = nil })
                .accessibilityIdentifier("meal-share-system-sheet")
        }
        .onChange(of: model.snapshot == nil) { _, empty in if empty { dismiss() } }
    }

    private func contentToggle(_ title: String, keyPath: WritableKeyPath<MealShareContent, Bool>, id: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { model.content[keyPath: keyPath] },
            set: { enabled in
                var content = model.content
                content[keyPath: keyPath] = enabled
                model.setContent(content)
            }))
            .font(AppTypography.body)
            .frame(minHeight: 44)
            .accessibilityIdentifier("meal-share-include-\(id)")
    }
}
