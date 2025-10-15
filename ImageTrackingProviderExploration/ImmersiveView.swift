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
  @State private var diagnosticsEntity: Entity?
  @State private var diagnosticsAnchor: Entity?

  private enum OverlayConstants {
    static let indicatorRadius: Float = 0.055
    static let indicatorLift: Float = 0.05
    static let billboardClearance: Float = 0.18
    static let minimumPlaneDimension: Float = 0.05
  }

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
      ensureDiagnosticsEntity(on: root)
    } update: { _ in
      guard let rootEntity else { return }
      syncOverlayEntities(on: rootEntity)
      ensureDiagnosticsEntity(on: rootEntity)
    }
    .task {
      appModel.frameRateMonitor.start()
      appModel.magnetTracker.start()
    }
    .onDisappear {
      appModel.magnetTracker.stop()
      appModel.frameRateMonitor.stop()
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
      updateOverlay(entity, with: overlay)
    }

    for (id, entity) in overlayEntities where !activeIdentifiers.contains(id) {
      entity.removeFromParent()
      overlayEntities.removeValue(forKey: id)
    }
  }

  private func makeOverlayEntity(for state: MagnetTracker.OverlayState) -> Entity {
    let root = Entity()
    root.name = "overlay-root"

    let dimensions = footprintDimensions(for: state)

    let footprint = ModelEntity(
      mesh: .generatePlane(width: dimensions.width, height: dimensions.height),
      materials: [footprintMaterial(isTracked: state.isTracked)]
    )
    footprint.name = "anchor-footprint"
    footprint.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    footprint.position = [0, 0, -0.001]
    root.addChild(footprint)

    let indicator = ModelEntity(
      mesh: .generateSphere(radius: OverlayConstants.indicatorRadius),
      materials: [indicatorMaterial(isTracked: state.isTracked)]
    )
    indicator.name = "tracking-indicator"
    indicator.position = indicatorPosition(for: state)
    root.addChild(indicator)

    let billboard = Entity()
    billboard.name = "overlay-billboard"
    billboard.position = billboardPosition(for: state)
    billboard.components.set(BillboardComponent())

    let cardHolder = Entity()
    cardHolder.name = "overlay-card"
    cardHolder.components.set(ViewAttachmentComponent(rootView: MagnetOverlayView(state: state)))
    billboard.addChild(cardHolder)

    root.addChild(billboard)

    return root
  }

  private func ensureDiagnosticsEntity(on root: Entity) {
    let anchor: Entity = {
      if let existing = diagnosticsAnchor {
        if existing.parent == nil {
          root.addChild(existing)
        }
        return existing
      } else {
        let newAnchor = Entity()
        newAnchor.components.set(AnchoringComponent(.head))
        root.addChild(newAnchor)
        diagnosticsAnchor = newAnchor
        return newAnchor
      }
    }()

    let desiredPosition = SIMD3<Float>(0, 0.32, -1.0)

    if let existingPanel = diagnosticsEntity {
      if existingPanel.parent == nil {
        anchor.addChild(existingPanel)
      }
      existingPanel.position = desiredPosition
      return
    }

    let panelEntity = Entity()
    panelEntity.position = desiredPosition
    panelEntity.components.set(
      ViewAttachmentComponent(
        rootView: DiagnosticsPanel()
          .padding(18)
          .allowsHitTesting(false)
      )
    )
    panelEntity.components.set(BillboardComponent())
    anchor.addChild(panelEntity)
    diagnosticsEntity = panelEntity
  }

  private func updateOverlay(_ entity: Entity, with overlay: MagnetTracker.OverlayState) {
    if let cardHolder = entity.findEntity(named: "overlay-card") {
      cardHolder.components.set(ViewAttachmentComponent(rootView: MagnetOverlayView(state: overlay)))
    }
    updateBillboard(for: entity, overlay: overlay)
    updateIndicator(for: entity, overlay: overlay)
    updateFootprint(for: entity, overlay: overlay)
  }

  private func updateIndicator(for entity: Entity, overlay: MagnetTracker.OverlayState) {
    guard let indicator = entity.findEntity(named: "tracking-indicator") as? ModelEntity else { return }
    indicator.model?.materials = [indicatorMaterial(isTracked: overlay.isTracked)]
    indicator.scale = overlay.isTracked ? .one : SIMD3<Float>(repeating: 0.75)
    indicator.position = indicatorPosition(for: overlay)
  }

  private func updateBillboard(for entity: Entity, overlay: MagnetTracker.OverlayState) {
    guard let billboard = entity.findEntity(named: "overlay-billboard") else { return }
    billboard.position = billboardPosition(for: overlay)
  }

  private func updateFootprint(for entity: Entity, overlay: MagnetTracker.OverlayState) {
    guard let footprint = entity.findEntity(named: "anchor-footprint") as? ModelEntity else { return }
    footprint.model?.materials = [footprintMaterial(isTracked: overlay.isTracked)]
    footprint.scale = SIMD3<Float>(repeating: max(overlay.estimatedScaleFactor, 0.001))
  }

  private func billboardPosition(for overlay: MagnetTracker.OverlayState) -> SIMD3<Float> {
    let dimensions = footprintDimensions(for: overlay)
    let halfHeight = dimensions.height * overlay.estimatedScaleFactor * 0.5
    return SIMD3<Float>(0, halfHeight + OverlayConstants.billboardClearance, 0.02)
  }

  private func indicatorPosition(for overlay: MagnetTracker.OverlayState) -> SIMD3<Float> {
    let dimensions = footprintDimensions(for: overlay)
    let halfHeight = dimensions.height * overlay.estimatedScaleFactor * 0.5
    return SIMD3<Float>(0, halfHeight + OverlayConstants.indicatorLift, 0.015)
  }

  private func footprintDimensions(for overlay: MagnetTracker.OverlayState) -> (width: Float, height: Float) {
    let minDimension = OverlayConstants.minimumPlaneDimension
    let width = max(Float(overlay.referenceSize.width), minDimension)
    let height = max(Float(overlay.referenceSize.height), minDimension)
    return (width, height)
  }

  private func footprintMaterial(isTracked: Bool) -> SimpleMaterial {
    let color = isTracked
      ? SimpleMaterial.Color(red: 0.18, green: 0.56, blue: 0.95, alpha: 0.22)
      : SimpleMaterial.Color(red: 0.96, green: 0.56, blue: 0.19, alpha: 0.18)
    return SimpleMaterial(color: color, roughness: 0.35, isMetallic: false)
  }

  private func indicatorMaterial(isTracked: Bool) -> SimpleMaterial {
    let color = isTracked
      ? SimpleMaterial.Color(red: 0.23, green: 0.83, blue: 0.32, alpha: 1.0)
      : SimpleMaterial.Color(red: 0.95, green: 0.64, blue: 0.18, alpha: 1.0)
    return SimpleMaterial(color: color, roughness: 0.25, isMetallic: false)
  }
}

#Preview(immersionStyle: .progressive) {
  ImmersiveView()
    .environment(AppModel())
}
