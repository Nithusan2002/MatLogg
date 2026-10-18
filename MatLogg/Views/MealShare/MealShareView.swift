import SwiftUI

struct MealShareView: View {
    @ObservedObject var model: MealShareViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if model.isPreparing { ProgressView("Klargjør kort …") }
                    if let snapshot = model.snapshot {
                        TabView(selection: Binding(get: { model.style }, set: { model.select($0) })) {
                            ForEach(MealShareStyle.allCases) { style in
                                GeometryReader { geometry in
                                    MealShareCardView(snapshot: snapshot, style: style, photo: model.photo)
                                        .scaleEffect(min(geometry.size.width / 360, geometry.size.height / 640))
                                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                }
                                .padding(.horizontal, 8)
                                .tag(style)
                                .accessibilityLabel("\(style.title) måltidskort")
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 440)
                        .disabled(model.isExporting)
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                        layout {
                            ForEach(MealShareStyle.allCases) { style in
                                Button {
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { model.select(style) }
                                } label: {
                                    VStack(spacing: 8) {
                                        MealShareCardView(snapshot: snapshot, style: style, photo: model.photo)
                                            .scaleEffect(0.15)
                                            .frame(width: 54, height: 96)
                                            .accessibilityHidden(true)
                                        Label(style.title, systemImage: model.style == style ? "checkmark.circle.fill" : "circle")
                                            .font(AppTypography.captionEmphasis)
                                    }.frame(maxWidth: .infinity, minHeight: 44).padding(8)
                                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.style == style ? AppColors.action : AppColors.separator, lineWidth: 2))
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
                    Text("Deler bilde, måltidsnavn og næringsinnhold.").font(AppTypography.caption)
                    if let warning = model.photoWarning { Text(warning).font(AppTypography.caption) }
                    if let error = model.errorMessage { ErrorMessageView(error) }
                }.padding(16)
            }
            .accessibilityIdentifier("meal-share-scroll")
            .background(AppColors.background)
            .navigationTitle("Del måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Lukk") { dismiss() }.accessibilityIdentifier("meal-share-close") } }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: model.isExporting ? "Lager kort …" : "Del kortet") {
                    Task { await model.export() }
                }
                .disabled(model.snapshot == nil || model.isPreparing || model.isExporting)
                .accessibilityIdentifier("meal-share-export")
                .padding(16).background(AppColors.background)
            }
        }
        .sheet(item: $model.sharedImage) { item in ShareSheet(activityItems: [item.image]).accessibilityIdentifier("meal-share-system-sheet") }
        .onChange(of: model.snapshot == nil) { _, empty in if empty { dismiss() } }
    }
}
