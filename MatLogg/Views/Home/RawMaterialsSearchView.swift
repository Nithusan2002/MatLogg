import SwiftUI

struct RawMaterialsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showScanCamera = false
    let onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        NavigationStack {
            FoodSearchView(
                focusOnAppear: true,
                onScan: { showScanCamera = true },
                onLogComplete: complete
            )
            .navigationTitle("Søk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lukk") { dismiss() }.foregroundColor(AppColors.action)
                }
            }
        }
        .fullScreenCover(isPresented: $showScanCamera) {
            CameraView(onLogComplete: complete)
        }
    }

    private func complete(_ payload: ReceiptPayload) {
        dismiss()
        onLogComplete(payload)
    }
}
