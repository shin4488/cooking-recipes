import SwiftUI

/// 保存などの結果を数秒だけ表示する。読み上げでも伝える
struct ToastView: View {
    @Environment(RecipeStore.self) private var store

    var body: some View {
        ZStack {
            if let toast = store.toast {
                HStack(spacing: 12) {
                    Text(toast.message)
                        .font(.subheadline)
                    if let title = toast.actionTitle, let action = toast.action {
                        Button(title) {
                            store.toast = nil
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
                    withAnimation { if store.toast?.id == toast.id { store.toast = nil } }
                }
            }
        }
        .animation(.default, value: store.toast)
    }
}
