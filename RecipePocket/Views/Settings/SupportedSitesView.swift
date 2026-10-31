import RecipeCore
import SwiftUI

struct SupportedSitesView: View {
    var body: some View {
        List {
            Section {
                Text("次のサイトの公開レシピを登録すると、保存後にこの端末からページのタイトルを取得します。ほかのサイトはURLを保存し、タイトルは共有元から受け取るか、手入力します。")
            }
            Section("対応サイト") {
                ForEach(SupportedSite.all) { site in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(site.name)
                            .font(.headline)
                        ForEach(site.coveredLocations, id: \.self) { location in
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section {
                Text("取得するのはタイトルだけです。本文・写真・動画は保存しません。各サイトの運営会社とは提携していません。")
            }
        }
        .navigationTitle("対応サイト")
        .analyticsScreen(.supportedSites)
    }
}
