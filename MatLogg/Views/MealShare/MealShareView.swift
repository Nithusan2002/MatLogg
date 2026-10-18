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
                            Picker("Bildeformat", selection: Binding(get: { model.format }, set: { model.selectFormat($0) })) {
                                ForEach(MealShareFormat.allCases) { format in
                                    Text(format.title).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Bildeformat")
                            .accessibilityIdentifier("meal-share-format")
                            .disabled(model.isWorking)
                            TabView(selection: Binding(get: { model.style }, set: { model.select($0) })) {
                                ForEach(MealShareStyle.allCases) { style in
                                    GeometryReader { geometry in
                                        let width = min(geometry.size.width - 24, (geometry.size.height - 16) * model.format.aspectRatio)
                                        MealShareCardView(snapshot: snapshot, style: style, photo: model.photo, content: model.content, format: model.format)
                                            .scaleEffect(width / 360)
                                            .frame(width: width, height: width / model.format.aspectRatio)
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
                                : min(500, max(200, available.size.height - 288)))
                            .disabled(model.isWorking)
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
                                            MealShareCardView(snapshot: snapshot, style: style, photo: model.photo, content: model.content, format: model.format)
                                                .scaleEffect(96 / model.format.canvasSize.height)
                                                .frame(width: 96 * model.format.aspectRatio, height: 96)
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
                                    .disabled(model.isWorking)
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
                        .disabled(model.isWorking || model.snapshot == nil)
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
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Button {
                        Task { await model.saveToPhotos() }
                    } label: {
                        Text(model.isSaving ? "Lagrer …" : "Lagre bilde")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(AppColors.surface, in: Capsule())
                            .overlay(Capsule().stroke(AppColors.controlBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("meal-share-save")
                    PrimaryButton(title: model.isExporting ? "Lager kort …" : "Del kortet") {
                        Task { await model.export() }
                    }
                    .accessibilityIdentifier("meal-share-export")
                }
                .disabled(model.snapshot == nil || model.isPreparing || model.isWorking)
                .padding(16).background(AppColors.background)
            }
        }
        .sheet(item: $model.sharedImage) { item in
            ShareSheet(activityItems: [item.image], onCompletion: { model.sharedImage = nil })
                .accessibilityIdentifier("meal-share-system-sheet")
        }
        .alert("Lagre bilde", isPresented: Binding(
            get: { model.saveNotice != nil },
            set: { if !$0 { model.saveNotice = nil } })) {
                Button("OK", role: .cancel) { model.saveNotice = nil }
            } message: {
                Text(model.saveNotice ?? "")
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
