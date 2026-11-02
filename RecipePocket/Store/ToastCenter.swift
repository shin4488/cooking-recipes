import Accessibility
import Foundation
import Observation

/// 画面下部に一時的に出す案内。操作を1つ付けられる
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

/// 画面下部の案内の状態と、表示する時間・読み上げ。一覧と設定の画面の下に出す（ToastView）。
/// 表示する画面が一覧と設定の間で替わっても、残りの時間だけ表示を続け、読み上げは出したときの1回にする
@MainActor
@Observable
final class ToastCenter {
    private(set) var toast: Toast?
    @ObservationIgnored private var dismissal: Task<Void, Never>?

    func show(_ message: String) {
        present(Toast(message: message))
    }

    func show(_ message: String, actionTitle: String, action: @escaping @MainActor () -> Void) {
        present(Toast(message: message, actionTitle: actionTitle, action: action))
    }

    /// 案内の操作を押したとき。案内を閉じてから操作を行う
    func performAction(of toast: Toast) {
        dismiss(toast)
        toast.action?()
    }

    private func present(_ toast: Toast) {
        self.toast = toast
        AccessibilityNotification.Announcement(toast.message).post()
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.action == nil ? 2 : 5))
            guard !Task.isCancelled else { return }
            self?.dismiss(toast)
        }
    }

    private func dismiss(_ toast: Toast) {
        guard self.toast?.id == toast.id else { return }
        self.toast = nil
    }
}
