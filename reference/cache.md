# iOS Cache Refactor Spec

## Objective

Reduce slow and repeated network work in the iOS Explore and Souler detail flows.

Primary constraints:

- Do not change Supabase schema in phase 1.
- Do not introduce thumbnail URLs in phase 1.
- Continue using the current original avatar/image URLs returned by existing APIs.
- Implement caching on iOS only for phase 1.
- Keep UI behavior native SwiftUI and avoid introducing large caching frameworks.

## Cache Ownership

Use different persistence mechanisms for different data shapes.

```text
Explore page payloads: JSON file cache
Avatar images: memory cache + disk file cache
Bookshelf history: SwiftData, later phase
```

Do not store image binary data in JSON or SwiftData.
Do not use SwiftData for the Explore page payload in phase 1.

## Phase 1 Scope

Implement only:

- Explore JSON cache.
- Shared remote image cache.
- Replace Explore/Souler avatar image loading with the shared cached image component.

Do not implement in phase 1:

- Supabase schema changes.
- Supabase Storage thumbnail generation.
- CDN migration.
- SwiftData bookshelf migration.
- Full offline search.
- Local cache invalidation UI beyond a minimal stale-cache fallback.

## Explore JSON Cache

### Purpose

The Explore page should render cached content immediately when available, then refresh from Supabase in the background.

This cache prevents the Explore page from becoming empty or unusable when Supabase is slow or unreachable from the user's network.

### Storage

Store the cache as a Codable JSON file.

Recommended path:

```text
Application Support/ExploreCache/explore.json
```

Create the parent directory if missing.
Write atomically when possible.

### Payload Shape

Use the existing Explore list item model if it is already `Codable`. If it is not `Codable`, make it `Codable` without changing its app-facing behavior.

Recommended payload:

```swift
struct CachedExplorePayload: Codable {
    let savedAt: Date
    let featured: [ExploreSoulerItem]
    let latest: [ExploreSoulerItem]
}
```

If the current Explore implementation has category sections, include them in the same payload:

```swift
struct CachedExplorePayload: Codable {
    let savedAt: Date
    let featured: [ExploreSoulerItem]
    let latest: [ExploreSoulerItem]
    let categories: [ExploreCategorySection]
}
```

Keep the cache payload close to the data shape needed by the UI. Do not normalize it into many files.

### Loading Flow

On Explore view appearance:

1. Read `explore.json`.
2. If the cache exists and decodes successfully, render it immediately.
3. Start a network refresh in the background.
4. If the refresh succeeds, update the view state and overwrite `explore.json`.
5. If the refresh fails and cached data exists, keep showing cached data.
6. If the refresh fails and there is no cached data, show the existing empty/error UI.

### Suggested State

Use state that can distinguish first-load failure from refresh failure with cache.

```swift
enum ExploreLoadingState {
    case emptyLoading
    case showingCacheRefreshing
    case fresh
    case staleCacheFailed
    case emptyFailed
}
```

Do not block rendering cached data while waiting for Supabase.

### Cache Age

Store `savedAt`.

Phase 1 behavior:

- Always allow cached data to render first.
- Refresh in the background whenever the Explore page appears.
- Do not hide cached data solely because it is old.

Optional later behavior:

- Use TTL to skip background refresh for very recent caches.
- Use `savedAt` to show subtle stale-state diagnostics during development.

## Avatar Image Cache

### Purpose

Avoid downloading the same avatar image repeatedly across app launches, tab switches, Explore list scrolling, and Souler detail navigation.

### URL Source

Use the existing original avatar/image URL returned by current app data flows.

Do not add or require:

- `avatar_thumb_url`
- transformed Supabase image URLs
- new image-size fields
- server-side thumbnail jobs

If the URL changes in the future, the cache key changes naturally and a new image will be downloaded.

### Storage

Use two layers:

```text
NSCache<NSURL, UIImage>
Caches/AvatarCache/<sha256(url)>
```

Memory cache handles repeated usage within the same app session.
Disk cache handles reuse across launches.

### File Key

Use SHA256 of the absolute URL string.

Do not use the raw URL as a filename.

### Loading Flow

For a given image URL:

1. Return the memory-cached image if present.
2. Else return the disk-cached image if present, and promote it to memory cache.
3. Else download the image.
4. Decode it as `UIImage`.
5. Store it in memory and disk.
6. Render the downloaded image.
7. If download or decode fails, render the caller-provided placeholder.

### Suggested Files

```text
ios/Velune/Velune/Services/ImageDiskCache.swift
ios/Velune/Velune/Views/Components/CachedRemoteImage.swift
```

`CachedRemoteImage` should be reusable by Explore cards and Souler detail.

### Component Requirements

`CachedRemoteImage` should:

- Accept `URL?`.
- Accept a placeholder view or provide a simple default.
- Use Swift concurrency.
- Avoid duplicate visible flicker when reused in scrolling lists.
- Cancel in-flight tasks when the view disappears or URL changes.
- Keep the public API small.

Example shape:

```swift
struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode
    @ViewBuilder let placeholder: () -> Placeholder
}
```

## Bookshelf SwiftData

Bookshelf persistence is a later phase.

When implemented, use SwiftData because bookshelf data is user history and may need local sorting, filtering, editing, deletion, pinning, and long-term persistence.

Potential model:

```swift
@Model
final class BookshelfRecord {
    @Attribute(.unique) var soulerId: String
    var soulerName: String
    var avatarURL: URL?
    var lastSessionId: String?
    var lastMessagePreview: String?
    var lastOpenedAt: Date
    var updatedAt: Date
}
```

Do not mix bookshelf SwiftData migration into the phase 1 Explore/avatar cache implementation unless explicitly requested.

## Implementation Order

1. Add `ImageDiskCache`.
2. Add `CachedRemoteImage`.
3. Replace avatar loading in Explore cards with `CachedRemoteImage`.
4. Replace avatar loading in Souler detail with `CachedRemoteImage`.
5. Add Explore JSON cache store.
6. Wire Explore view to render cached data first and refresh in the background.
7. Build the iOS app.
8. Manually verify cold cache and warm cache behavior.

## Acceptance Criteria

Phase 1 is complete when:

- Explore renders cached content immediately after the first successful load.
- Explore keeps cached content visible if Supabase refresh fails.
- Avatar images are reused from memory during the same app session.
- Avatar images are reused from disk after app relaunch.
- Explore and Souler detail use the same cached image component.
- No Supabase schema or API contract changes are required.
- `xcodebuild` succeeds for the iOS app.

## Notes for Future Phases

Future optimizations may include:

- Supabase-side `avatar_thumb_url`.
- A mobile-specific public souler view.
- CDN migration for image assets.
- SwiftData bookshelf persistence.
- TTL-based refresh throttling.
- ETag or `Last-Modified` based revalidation.

These are intentionally out of scope for phase 1.

