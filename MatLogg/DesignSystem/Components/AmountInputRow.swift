import SwiftUI

struct AmountInputRow: View {
    let title: String
    @Binding var gramsText: String
    let unit: String
    let placeholder: String
    let onFocus: (() -> Void)?
    
    init(
        title: String = "Mengde",
        gramsText: Binding<String>,
        unit: String = "g",
        placeholder: String = "0",
        onFocus: (() -> Void)? = nil
    ) {
        self.title = title
        self._gramsText = gramsText
        self.unit = unit
        self.placeholder = placeholder
        self.onFocus = onFocus
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.ink)
            
            Spacer()
            
            SelectAllTextField(text: $gramsText, placeholder: placeholder, onFocus: onFocus)
                .font(.system(size: 22, weight: .semibold))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10)
                .frame(width: 76)
                .frame(height: 40)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.separator, lineWidth: 1)
                )
                .cornerRadius(12)
            
            Text(unit)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.textSecondary)
        }
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
        field.keyboardType = .numberPad
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
