import SwiftUI

struct TermsView: View {
    var body: some View {
        List {
            ForEach(PolicyText.terms(operator: AppInfo.policyOperator), id: \.title) { section in
                Section(section.title ?? "") {
                    ForEach(section.paragraphs, id: \.self) { Text($0) }
                }
            }
        }
        .navigationTitle(PolicyText.termsTitle)
        .analyticsScreen(.terms)
    }
}
