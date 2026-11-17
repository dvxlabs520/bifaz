import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

@main
struct BifazApp: App {
    /// `nil` when the store could not be opened; the app then shows `StoreErrorView`.
    private let container: ModelContainer?

    init() {
        Appearance.configureNavigationBars()
        do {
            container = try BifazStore.makeContainer()
        } catch {
            Log.app.error("Store failed to open: \(String(describing: error), privacy: .public)")
            container = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "BifazDesignGallery") {
                    DesignGalleryView()
                } else {
                    RootView().modelContainer(container)
                }
                #else
                RootView().modelContainer(container)
                #endif
            } else {
                StoreErrorView()
            }
        }
    }
}
