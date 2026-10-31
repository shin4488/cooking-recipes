import SwiftUI

/// 外部送信の公表と、利用状況の送信の設定
struct PrivacyView: View {
    @State private var analyticsEnabled = AppAnalytics.shared.isEnabled

    var body: some View {
        List {
            ForEach(Array(PolicyText.privacy.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(section.paragraphs, id: \.self) { Text($0) }
                    ForEach(section.destinations, id: \.name) { destination in
                        DestinationRow(destination: destination)
                        ForEach(destination.links, id: \.url) { link in
                            Link(link.title, destination: link.url)
                        }
                    }
                } header: {
                    if let title = section.title { Text(title) }
                }
            }

            Section {
                Toggle("利用状況を送る", isOn: $analyticsEnabled)
                    .onChange(of: analyticsEnabled) { _, enabled in
                        AppAnalytics.shared.isEnabled = enabled
                    }
            } header: {
                Text("利用状況の送信")
            } footer: {
                Text("オフにすると、この端末から Google Analytics へ情報を送りません。")
            }

            Section("運営者") {
                LabeledContent("運営者", value: AppInfo.policyOperator.name)
                LabeledContent("問い合わせ先", value: AppInfo.policyOperator.contactEmail)
            }
        }
        .navigationTitle(PolicyText.privacyTitle)
        .analyticsScreen(.privacy)
    }
}

private struct DestinationRow: View {
    let destination: PolicyText.Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(destination.name)
                .font(.headline)
            Text("送る情報：\(destination.information)")
            Text("目的：\(destination.purpose)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
