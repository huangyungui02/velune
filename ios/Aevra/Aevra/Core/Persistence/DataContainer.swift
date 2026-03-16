import SwiftData

@Observable
@MainActor
class DataContainer {
    let modelContainer: ModelContainer

    var context: ModelContext {
        modelContainer.mainContext
    }

    init(inMemoryOnly: Bool = false) {
        let schema = Schema([
            Glimmer.self,
            Echo.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemoryOnly
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            try context.save()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
