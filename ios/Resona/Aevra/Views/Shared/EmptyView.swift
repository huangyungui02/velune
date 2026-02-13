import SwiftUI

struct EmptyView: View {
    let title: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "sparkles")
        }
    }
}
