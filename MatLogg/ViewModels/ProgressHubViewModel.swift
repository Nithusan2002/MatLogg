import Foundation
import Combine

@MainActor
final class ProgressHubViewModel: ObservableObject {
    @Published private(set) var layout = ProgressHubLayout.standard(hasWeightHistory: false)
    @Published private(set) var draft: ProgressHubLayout?
    @Published private(set) var errorMessage: String?
    @Published private(set) var owner: UUID?
    private let repository: any ProgressHubRepository
    private var hasSavedLayout = false
    private var defaultResolved = false
    private var hasWeightHistory = false

    init(repository: any ProgressHubRepository) { self.repository = repository }

    func activate(owner: UUID?) {
        guard self.owner != owner else { return }
        reset()
        self.owner = owner
        guard let owner else { return }
        if let saved = repository.load(owner: owner) {
            layout = saved
            hasSavedLayout = true
        }
    }

    func updateDefault(hasWeightHistory: Bool, owner: UUID) {
        guard self.owner == owner else { return }
        self.hasWeightHistory = hasWeightHistory
        if !hasSavedLayout && !defaultResolved {
            layout = .standard(hasWeightHistory: hasWeightHistory)
            defaultResolved = true
        }
    }

    func beginEditing() {
        guard owner != nil else { return }
        errorMessage = nil
        draft = layout
    }

    func setVisible(_ area: ProgressHubArea, isVisible: Bool) {
        guard draft != nil else { return }
        if isVisible { draft?.visible.insert(area) } else { draft?.visible.remove(area) }
    }

    func move(_ area: ProgressHubArea, by offset: Int) {
        guard var value = draft, let index = value.order.firstIndex(of: area),
              value.order.indices.contains(index + offset) else { return }
        value.order.swapAt(index, index + offset)
        draft = value
    }

    func restoreDefault() {
        guard draft != nil, owner != nil else { return }
        draft = .standard(hasWeightHistory: hasWeightHistory)
    }
    func cancelEditing() { draft = nil; errorMessage = nil }

    @discardableResult
    func save() -> Bool {
        guard let owner, let draft else { return false }
        do {
            try repository.save(draft, owner: owner)
            layout = draft
            hasSavedLayout = true
            cancelEditing()
            return true
        } catch {
            errorMessage = "Kunne ikke lagre oversikten. Prøv igjen."
            return false
        }
    }

    func reset() {
        owner = nil
        hasSavedLayout = false
        defaultResolved = false
        hasWeightHistory = false
        layout = .standard(hasWeightHistory: false)
        cancelEditing()
    }
}
