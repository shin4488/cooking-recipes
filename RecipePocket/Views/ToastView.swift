import SwiftUI

/// 保存などの結果を画面下部に表示する。表示する時間と読み上げは ToastCenter が受け持つ
struct ToastView: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        ZStack {
            if let toast = toasts.toast {
                HStack(spacing: 12) {
                    Text(toast.message)
                        .font(.subheadline)
                    if let title = toast.actionTitle, toast.action != nil {
                        Button(title) {
                            toasts.performAction(of: toast)
                        }
                        .font(.subheadline.bold())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: .capsule)
                .shadow(radius: 4, y: 2)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: toasts.toast)
    }
}
