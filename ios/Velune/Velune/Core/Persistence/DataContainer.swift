import SwiftData

@Observable
@MainActor
class DataContainer {
    let modelContainer: ModelContainer

    var context: ModelContext {
        modelContainer.mainContext
    }

    init(inMemoryOnly: Bool = false) throws {
        let schema = Schema([
            Glimmer.self,
            Resonance.self,
            CachedChatSession.self,
            CachedMessage.self,
            MessageCacheBucket.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemoryOnly
        )

        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        try context.save()
    }
}
