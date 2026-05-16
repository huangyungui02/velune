import SwiftUI

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var loadedURL: URL?
    @State private var image: UIImage?

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image, loadedURL == url {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url else {
            loadedURL = nil
            image = nil
            return
        }

        if loadedURL != url {
            image = nil
        }

        let fetchedImage = await ImageDiskCache.shared.image(for: url)
        guard !Task.isCancelled, self.url == url else { return }
        loadedURL = url
        image = fetchedImage
    }
}
