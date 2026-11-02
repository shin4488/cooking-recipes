import SwiftUI

/// 保存などの結果を数秒だけ表示する。読み上げでも伝える
struct ToastView: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        ZStack {
            if let toast = toasts.toast {
                HStack(spacing: 12) {
                    Text(toast.message)
                        .font(.subheadline)
                    if let title = toast.actionTitle, let action = toast.action {
                        Button(title) {
                            toasts.toast = nil
                            action()
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
                .task(id: toast.id) {
                    AccessibilityNotification.Announcement(toast.message).post()
                    try? await Task.sleep(for: .seconds(toast.action == nil ? 2 : 5))
                    withAnimation { if toasts.toast?.id == toast.id { toasts.toast = nil } }
                }
            }
        }
        .animation(.default, value: toasts.toast)
    }
}
