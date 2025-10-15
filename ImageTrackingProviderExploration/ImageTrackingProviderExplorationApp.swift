//
//  ImageTrackingProviderExplorationApp.swift
//  ImageTrackingProviderExploration
//
//  Created by Cristian Díaz on 08.10.25.
//

import SwiftUI

@main
struct ImageTrackingProviderExplorationApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .progressive, .mixed)
    }
}
