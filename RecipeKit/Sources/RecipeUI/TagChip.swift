import SwiftUI

/// タグの見た目。タップで操作する場合は Button のラベルに使う
public struct TagChip: View {
    private let text: String
    private let systemImage: String?

    public init(_ text: String, systemImage: String? = nil) {
        self.text = text
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(.tint)
        // 文字とのコントラスト比 4.5:1 以上を保つ濃さ
        .background(.tint.opacity(0.08), in: .capsule)
        .contentShape(.capsule)
    }
}

/// ×で外せるチップ。×の操作を読み上げで分かるようにする
public struct RemovableChip: View {
    private let text: String
    private let removalLabel: String
    private let onRemove: () -> Void

    public init(_ text: String, removalLabel: String, onRemove: @escaping () -> Void) {
        self.text = text
        self.removalLabel = removalLabel
        self.onRemove = onRemove
    }

    public var body: some View {
        Button(action: onRemove) {
            TagChip(text, systemImage: "xmark")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint(removalLabel)
    }
}
