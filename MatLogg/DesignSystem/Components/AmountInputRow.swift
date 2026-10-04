import SwiftUI

struct AmountInputRow: View {
    let title: String
    @Binding var gramsText: String
    let unit: String
    let placeholder: String
    let onFocus: (() -> Void)?
    let showsTitle: Bool
    let controlWidth: CGFloat?
    
    init(
        title: String = "Mengde",
        gramsText: Binding<String>,
        unit: String = "g",
        placeholder: String = "0",
        onFocus: (() -> Void)? = nil,
        showsTitle: Bool = true,
        controlWidth: CGFloat? = nil
    ) {
        self.title = title
        self._gramsText = gramsText
        self.unit = unit
        self.placeholder = placeholder
        self.onFocus = onFocus
        self.showsTitle = showsTitle
        self.controlWidth = controlWidth
    }
    
    var body: some View {
        HStack(spacing: 10) {
            if showsTitle {
                Text(title)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.ink)
                Spacer()
            }
            
            HStack(spacing: 8) {
                SelectAllTextField(text: $gramsText, placeholder: placeholder, onFocus: onFocus)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
                .accessibilityValue("\(gramsText) \(unit)")

                if controlWidth != nil && !unit.isEmpty {
                    unitLabel
                }
            }
                .padding(.horizontal, 10)
                .frame(width: controlWidth ?? 76)
                .frame(minHeight: 44)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.controlBorder, lineWidth: 1)
                )
                .cornerRadius(12)
            
            if controlWidth == nil && !unit.isEmpty {
                unitLabel
            }
        }
    }

    private var unitLabel: some View {
        Text(unit)
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(AppColors.textSecondary)
            .fixedSize()
    }
}

struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onFocus: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.textAlignment = .right
        field.keyboardType = .decimalPad
        field.placeholder = placeholder
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return field
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onFocus: onFocus)
    }
    
    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onFocus: (() -> Void)?
        
        init(text: Binding<String>, onFocus: (() -> Void)?) {
            self._text = text
            self.onFocus = onFocus
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
                self.onFocus?()
            }
        }
        
        @objc func editingChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}
