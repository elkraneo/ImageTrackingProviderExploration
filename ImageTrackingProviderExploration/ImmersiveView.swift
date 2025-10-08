//
//  ImmersiveView.swift
//  ImageTrackingProviderExploration
//
//  Created by Cristian Díaz on 08.10.25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {

  @Environment(AppModel.self) private var appModel

  @State private var rootEntity: Entity?
  @State private var overlayEntities: [UUID: Entity] = [:]

  var body: some View {
    RealityView { content in
      if let immersiveContentEntity = try? await Entity(
        named: "Immersive",
        in: realityKitContentBundle
      ) {
        content.add(immersiveContentEntity)
      }

      let root = Entity()
      rootEntity = root
      content.add(root)
    } update: { _ in
      guard let rootEntity else { return }
      syncOverlayEntities(on: rootEntity)
    }
    .task {
      appModel.magnetTracker.start()
    }
    .onDisappear {
      appModel.magnetTracker.stop()
    }
  }

  private func syncOverlayEntities(on root: Entity) {
    // RealityView rebuilds entities on every update pass, so keep a local cache to
    // create/remove attachment entities that mirror the tracker state.
    var activeIdentifiers = Set<UUID>()

    for overlay in appModel.magnetTracker.overlays.values {
      let entity = overlayEntities[overlay.id] ?? makeOverlayEntity(for: overlay)
      overlayEntities[overlay.id] = entity
      activeIdentifiers.insert(overlay.id)

      if entity.parent == nil {
        root.addChild(entity)
      }

      entity.transform = overlay.transform
      entity.components.set(
        ViewAttachmentComponent(rootView: MagnetOverlayView(state: overlay))
      )
    }

    for (id, entity) in overlayEntities where !activeIdentifiers.contains(id) {
      entity.removeFromParent()
      overlayEntities.removeValue(forKey: id)
    }
  }

  private func makeOverlayEntity(for state: MagnetTracker.OverlayState) -> Entity {
    let entity = Entity()
    entity.components.set(ViewAttachmentComponent(rootView: MagnetOverlayView(state: state)))
    return entity
  }
}

#Preview(immersionStyle: .progressive) {
  ImmersiveView()
    .environment(AppModel())
}
