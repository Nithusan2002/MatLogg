import SwiftUI

struct WaterCardView: View {
    @ObservedObject var viewModel: WaterViewModel
    let userId: UUID?
    let date: Date
    var compact = false
    var embedded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                CardContainer { content }
            }
        }
        .task(id: context) { await viewModel.load(userId: userId, date: date) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if embedded && !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 12) {
                    summary.frame(maxWidth: .infinity, alignment: .leading)
                    waterControls.fixedSize(horizontal: true, vertical: false)
                }
            } else if embedded {
                VStack(alignment: .leading, spacing: 8) { summary; waterControls }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { summary; Spacer(minLength: 8); waterControls }
                    VStack(alignment: .leading, spacing: 8) { summary; waterControls }
                }
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
        .foregroundStyle(embedded ? AppColors.energyTextSecondary : AppColors.textSecondary)
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

    private var waterStatus: Text {
        guard viewModel.isLoaded else { return Text("Henter …") }
        guard embedded else { return Text("\(viewModel.glasses.count) glass") }

        let isToday = Calendar.current.isDateInToday(date)
        let day = isToday ? "i dag" : "denne dagen"
        if viewModel.glasses.isEmpty {
            return Text("Ingen glass registrert \(day)")
        }
        let amount = Text("\(viewModel.glasses.count) glass").bold()
        if isToday {
            return Text("Du har drukket \(amount) i dag")
        }
        return Text("Du registrerte \(amount) denne dagen")
    }

    private var summary: some View {
        HStack(spacing: 10) {
            if compact {
                Image(systemName: "drop.fill")
                    .foregroundStyle(AppColors.info)
                    .frame(width: 32, height: 32)
                    .background(embedded ? AppColors.mutedSurface : AppColors.info.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(embedded ? "Husk å drikke vann" : waterTitle)
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(embedded ? AppColors.energyTextSecondary : AppColors.textSecondary)
                waterStatus
                    .font(embedded ? AppTypography.secondary : (compact ? AppTypography.bodyEmphasis : AppTypography.title))
                    .foregroundStyle(AppColors.deepInk)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.isLoaded ? "\(waterTitle), \(viewModel.glasses.count) glass" : "\(waterTitle), henter")
        .accessibilityIdentifier("water-count")
        .accessibilityValue(String(viewModel.glasses.count))
    }

    private var waterControls: some View {
        HStack(spacing: 8) {
            Button { Task { await viewModel.remove() } } label: {
                waterButtonLabel(symbol: "minus")
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isLoaded || viewModel.glasses.isEmpty || viewModel.isBusy)
            .opacity(viewModel.glasses.isEmpty ? 0.45 : 1)
            .accessibilityLabel("Fjern ett glass vann")
            .accessibilityIdentifier("water-remove")
            addButton
        }
    }

    private func waterButtonLabel(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColors.deepInk)
            .frame(width: 44, height: 44)
            .background(WaterGlassButtonShape().fill(AppColors.mutedSurface))
            .overlay(WaterGlassButtonShape().stroke(AppColors.separator, lineWidth: 1))
            .contentShape(Rectangle())
    }

    private var addButton: some View {
        Button { Task { await viewModel.add() } } label: {
            waterButtonLabel(symbol: "plus")
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isLoaded || viewModel.isBusy)
        .accessibilityLabel("Legg til ett glass vann")
        .accessibilityIdentifier("water-add")
    }
}

/// A handle-free tumbler silhouette inside the full 44 pt button hit area.
private struct WaterGlassButtonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: 2, dy: 0.5)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: bounds.minX + bounds.width * x, y: bounds.minY + bounds.height * y)
        }
        var path = Path()
        path.move(to: point(0.12, 0))
        path.addLine(to: point(0.88, 0))
        path.addQuadCurve(to: point(1, 0.12), control: point(1, 0))
        path.addLine(to: point(0.88, 0.82))
        path.addQuadCurve(to: point(0.68, 1), control: point(0.85, 1))
        path.addLine(to: point(0.32, 1))
        path.addQuadCurve(to: point(0.12, 0.82), control: point(0.15, 1))
        path.addLine(to: point(0, 0.12))
        path.addQuadCurve(to: point(0.12, 0), control: point(0, 0))
        path.closeSubpath()
        return path
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
        // VoiceOver reads the full count from the summary above.
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
