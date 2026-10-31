import SwiftUI

/// 組み込んだオープンソースのライセンス。本文は Resources/ThirdPartyLicenses.txt に置く
struct LicensesView: View {
    private let text: String = {
        guard let url = Bundle.main.url(forResource: "ThirdPartyLicenses", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }()

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("ライセンス")
        .analyticsScreen(.licenses)
    }
}
