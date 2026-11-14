import Combine

/// Photo preview changes belong to the picker, not the complete editing form.
@MainActor
final class SavedMealFormState: ObservableObject {
    @Published private(set) var isSaving = false
    @Published private(set) var isLoadingPhoto = false
    @Published private(set) var errorMessage: String?

    init(viewModel: SavedMealsViewModel) {
        viewModel.$isSaving.removeDuplicates().assign(to: &$isSaving)
        viewModel.$isLoadingPhoto.removeDuplicates().assign(to: &$isLoadingPhoto)
        viewModel.$errorMessage.removeDuplicates().assign(to: &$errorMessage)
    }
}
