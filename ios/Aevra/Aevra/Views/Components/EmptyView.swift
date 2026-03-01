import SwiftUI

struct EmptyView: View {
    let title: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "sparkles")
        }
    }
}
