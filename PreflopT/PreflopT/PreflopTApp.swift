//
//  PreflopTApp.swift
//  PreflopT
//

import SwiftUI

@main
struct PreflopTApp: App {
    // The live container is constructed once per app launch. It loads the
    // bundled chart data synchronously; startup traps on bad data.
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.chartRepository, container.chartRepository)
        }
    }
}
