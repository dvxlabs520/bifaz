import SwiftData
import BifazModels

/// In-memory containers for SwiftUI previews.
enum PreviewContainer {
    static let empty: ModelContainer = {
        do {
            return try BifazStore.makeContainer(inMemory: true)
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()
}
