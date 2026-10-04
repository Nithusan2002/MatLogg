import SwiftUI

struct WaterCardView: View {
    @ObservedObject var viewModel: WaterViewModel
    let userId: UUID?
    let date: Date
    var compact = false
    var embedded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCorrection = false

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                CardContainer { content }
            }
        }
        .confirmationDialog("Juster vannloggen", isPresented: $showCorrection, titleVisibility: .visible) {
            Button("Fjern ett glass", role: .destructive) { Task { await viewModel.remove() } }
                .disabled(viewModel.glasses.isEmpty || viewModel.isBusy)
            Button("Avbryt", role: .cancel) {}
        }
        .task(id: context) { await viewModel.load(userId: userId, date: date) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { summary; Spacer(minLength: 8); waterControls }
                VStack(alignment: .leading, spacing: 8) { summary; waterControls }
            }
            if viewModel.isLoaded && !compact {
                WaterCupGrid(count: viewModel.glasses.count, reduceMotion: reduceMotion)
            }
            if let message = viewModel.errorMessage {
                ErrorMessageView(message).font(AppTypography.captionEmphasis)
                if !viewModel.isLoaded {
                    Button("Prøv igjen") { Task { await viewModel.load(userId: userId, date: date) } }
                        .frame(minHeight: 44)
                }
            }
        }
        .foregroundStyle(AppColors.textSecondary)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.mutationRevision)
    }

    private var waterTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Vann i dag" }
        if calendar.isDateInYesterday(date) { return "Vann i går" }
        if calendar.isDateInTomorrow(date) { return "Vann i morgen" }
        return "Vann \(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nb_NO"))))"
    }

    private var context: String { "\(userId?.uuidString ?? "")-\(date.timeIntervalSince1970)" }

    private var summary: some View {
        Button { showCorrection = true } label: {
            HStack(spacing: 10) {
                if compact {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(AppColors.info)
                        .frame(width: 32, height: 32)
                        .background(embedded ? AppColors.mutedSurface : AppColors.info.opacity(0.16), in: Circle())
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(embedded ? "Vann" : waterTitle)
                        .font(AppTypography.captionEmphasis)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(viewModel.isLoaded ? "\(viewModel.glasses.count) glass" : "Henter …")
                        .font(compact ? AppTypography.bodyEmphasis : AppTypography.title)
                        .foregroundStyle(AppColors.deepInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isLoaded || viewModel.isBusy)
        .accessibilityLabel(viewModel.isLoaded ? "\(waterTitle), \(viewModel.glasses.count) glass" : "\(waterTitle), henter")
        .accessibilityIdentifier("water-count")
        .accessibilityValue(String(viewModel.glasses.count))
        .accessibilityHint("Juster antall glass for valgt dag")
    }

    private var waterControls: some View {
        HStack(spacing: 8) {
            Button { Task { await viewModel.remove() } } label: {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(AppColors.deepInk)
                    .background(AppColors.mutedSurface, in: Circle())
                    .overlay(Circle().strokeBorder(AppColors.separator, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isLoaded || viewModel.glasses.isEmpty || viewModel.isBusy)
            .accessibilityLabel("Fjern ett glass vann")
            .accessibilityIdentifier("water-remove")
            addButton
        }
    }

    private var addButton: some View {
        Button { Task { await viewModel.add() } } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(AppColors.deepInk)
                .background(embedded ? AppColors.mutedSurface : AppColors.info.opacity(0.16), in: Circle())
                .overlay(Circle().strokeBorder(embedded ? AppColors.separator : AppColors.info.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isLoaded || viewModel.isBusy)
        .accessibilityLabel("Legg til ett glass vann")
        .accessibilityIdentifier("water-add")
    }
}

/// Fixed visual slots, not domain rows: the first ten remain in place when
/// glasses are added or removed; additional slots extend the same grid.
private struct WaterCupGrid: View {
    let count: Int
    let reduceMotion: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(0..<max(10, count), id: \.self) { slot in
                WaterCupIcon(isFilled: slot < count)
                    .frame(width: 40, height: 40)
                    .frame(maxWidth: .infinity)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        // Ten slots are a visual starting layout, not a recommended daily goal.
        // VoiceOver reads the full count from the button above.
        .accessibilityHidden(true)
    }
}

private struct WaterCupIcon: View {
    let isFilled: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .bottom) {
                WaterCupBowl().fill(AppColors.info.opacity(0.06))
                Rectangle()
                    .fill(LinearGradient(colors: [AppColors.info.opacity(0.45), AppColors.info], startPoint: .top, endPoint: .bottom))
                    .frame(height: isFilled ? size.height * 0.68 : 0)
                    .offset(y: -size.height * 0.12)
                    .frame(width: size.width, height: size.height, alignment: .bottom)
                    .clipShape(WaterCupBowl())
                WaterCupHandle()
                    .stroke(isFilled ? AppColors.info : AppColors.controlBorder, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                WaterCupBowl()
                    .stroke(isFilled ? AppColors.info : AppColors.controlBorder, style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WaterCupBowl: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.12, y: rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.width * 0.67, y: rect.height * 0.72))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.17, y: rect.height * 0.72),
            control: CGPoint(x: rect.width * 0.42, y: rect.height * 1.04)
        )
        path.closeSubpath()
        return path
    }
}

private struct WaterCupHandle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.29))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.65),
            control1: CGPoint(x: rect.width * 1.02, y: rect.height * 0.18),
            control2: CGPoint(x: rect.width * 1.02, y: rect.height * 0.68)
        )
        return path
    }
}
