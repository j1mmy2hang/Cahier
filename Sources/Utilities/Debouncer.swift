import Foundation

final class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private var pendingAction: (() -> Void)?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        pendingAction = action
        let item = DispatchWorkItem { [weak self] in
            self?.pendingAction?()
            self?.pendingAction = nil
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Execute any pending debounced action immediately.
    func flush() {
        workItem?.cancel()
        workItem = nil
        pendingAction?()
        pendingAction = nil
    }
}
