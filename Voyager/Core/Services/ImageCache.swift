import SwiftUI

// MARK: - In-memory image cache

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit       = 150
        cache.totalCostLimit   = 1024 * 1024 * 120  // ~120 MB
    }

    func get(_ url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func set(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
}

// MARK: - Image loader (Observable backing store)
//
// Using @Observable @MainActor avoids the classic SwiftUI pitfall where
// mutating @State vars from an async function after a suspension point
// silently drops the update (the task captures a value-type copy of self,
// so the assignment never reaches the live view storage).

@Observable
@MainActor
final class ImageLoader {
    var image: UIImage?

    private var loadedURL: URL?
    private var inflightTask: Task<Void, Never>?

    func load(url: URL) {
        // Nothing to do if this URL is already loaded or in-flight
        guard url != loadedURL else { return }

        // Cancel any previous download
        inflightTask?.cancel()
        inflightTask = nil

        // Instant cache hit — no task needed
        if let cached = ImageCache.shared.get(url) {
            image    = cached
            loadedURL = url
            return
        }

        image    = nil
        loadedURL = url

        inflightTask = Task {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            guard
                let (data, _) = try? await URLSession.shared.data(for: request),
                !Task.isCancelled,
                let img = UIImage(data: data)
            else { return }

            ImageCache.shared.set(img, for: url)
            image = img          // safe — we're @MainActor
        }
    }

    func cancel() {
        // Cancel the network fetch but keep the loaded image and URL so that
        // a cell that briefly disappears during LazyVGrid layout (and then
        // re-appears) doesn't lose its already-decoded image.
        inflightTask?.cancel()
        inflightTask = nil
    }

    func reset() {
        inflightTask?.cancel()
        inflightTask = nil
        loadedURL    = nil
        image        = nil
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content:     (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loader = ImageLoader()

    var body: some View {
        Group {
            if let ui = loader.image {
                content(Image(uiImage: ui))
            } else {
                placeholder()
            }
        }
        .onAppear {
            if let url { loader.load(url: url) }
        }
        .onChange(of: url) { _, newURL in
            if let newURL { loader.load(url: newURL) } else { loader.cancel() }
        }
        .onDisappear {
            // Cancel any in-flight download when the cell scrolls off screen,
            // but keep the already-decoded image so it's instant on re-appear.
            loader.cancel()
        }
    }
}
