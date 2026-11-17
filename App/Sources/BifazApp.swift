import SwiftUI
import SwiftData
import BifazModels
import BifazDesign

@main
struct BifazApp: App {
    @State private var loader = StoreLoader()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Appearance.configureNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            content
                .defaultAppStorage(AppDefaults.shared)
                .task { await loader.load() }
                // Hide amounts in the app switcher snapshot.
                .overlay {
                    if scenePhase != .active { BrandCover() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loader.state {
        case .loading:
            BrandCover()
        case .ready(let container):
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "BifazDesignGallery") {
                DesignGalleryView()
            } else {
                RootView().modelContainer(container)
            }
            #else
            RootView().modelContainer(container)
            #endif
        case .failed(let code):
            StoreErrorView(code: code) {
                Task { await loader.load() }
            }
        }
    }
}

/// Cobalt with the coin: identical to the launch screen, used while the store
/// opens and as the app-switcher cover.
struct BrandCover: View {
    var body: some View {
        Color.bifazBrandCobalt
            .ignoresSafeArea()
            .overlay { CoinMark(palette: .brand).frame(width: 200, height: 200) }
            .accessibilityHidden(true)
    }
}
