import SwiftData
import SwiftUI

@Observable
@MainActor
class DataContainer {
    let modelContainer: ModelContainer

    var context: ModelContext {
        modelContainer.mainContext
    }

    init(sampleData: Bool = false, inMemoryOnly: Bool = false) {
        let schema = Schema([
            Glimmer.self,
            Echo.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: sampleData || inMemoryOnly
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            if sampleData {
                loadSampleData()
            }
            try context.save()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func loadSampleData() {
        for (idx, glimmer) in Glimmer.sampleData.enumerated() {
            for echo in Echo.sampleData[idx*5 ..< idx*5 + 5] {
                glimmer.echoes.append(echo)
            }
            context.insert(glimmer)
        }
    }
}

private let sampleContainer = DataContainer(sampleData: true)

extension View {
    func sampleDataContainer() -> some View {
        modelContainer(sampleContainer.modelContainer)
    }
}
