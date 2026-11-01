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

/// 画面下部の案内の状態。一覧と設定の画面の下に出す（ToastView）
@MainActor
@Observable
final class ToastCenter {
    var toast: Toast?

    func show(_ message: String) {
        toast = Toast(message: message)
    }

    func show(_ message: String, actionTitle: String, action: @escaping @MainActor () -> Void) {
        toast = Toast(message: message, actionTitle: actionTitle, action: action)
    }
}
