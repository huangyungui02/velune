import SwiftUI

struct MapView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                Color.clear
            }
            .navigationTitle("app.tab.map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
