//
//  ContentView.swift
//  ImageTrackingProviderExploration
//
//  Created by Cristian Díaz on 08.10.25.
//

import RealityKit
import RealityKitContent
import SwiftUI

struct ContentView: View {

  @Environment(AppModel.self) private var appModel

  private let magnetSummaries:
    [(name: String, info: MagnetTracker.MagnetInfo)] = [
      (
        "espresso",
        MagnetTracker.MagnetInfo(
          title: "Espresso Shot",
          details: "Dial in a double in 25 seconds."
        )
      ),
      (
        "matcha",
        MagnetTracker.MagnetInfo(
          title: "Matcha Mood",
          details: "Whisk to 70°C and savor slowly."
        )
      ),
      (
        "market",
        MagnetTracker.MagnetInfo(
          title: "Farmer's Harvest",
          details: "Restock fresh greens every Sunday."
        )
      ),
    ]

  var body: some View {
    VStack(spacing: 32) {
      VStack(spacing: 16) {
        Model3D(named: "Scene", bundle: realityKitContentBundle)
          .frame(height: 140)

        Text("Fridge Magnet Guide")
          .font(.largeTitle).bold()

        Text(
          """
          Pin your magnet reference images in the FridgeMagnets AR resource group, \
          then open the immersive space to see contextual overlays on each match.
          """
        )
        .multilineTextAlignment(.center)
        .font(.callout)
        .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Magnet status")
          .font(.headline)

        Label(appModel.magnetTracker.statusDescription, systemImage: "eye")

        if let failureReason = appModel.magnetTracker.failureReason {
          Text(failureReason)
            .font(.footnote)
            .foregroundStyle(.red)
        }

        Text("Configured magnets")
          .font(.headline)
          .padding(.top, 8)

        ForEach(magnetSummaries, id: \.name) { summary in
          VStack(alignment: .leading, spacing: 4) {
            Text(summary.info.title)
              .font(.subheadline).bold()
            Text(summary.info.details)
              .font(.footnote)
              .foregroundStyle(.secondary)
            Text("Reference image name: \(summary.name)")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
          )
        }
      }
      .frame(maxWidth: 480, alignment: .leading)

      ToggleImmersiveSpaceButton()
    }
    .padding(40)
  }
}

#Preview(windowStyle: .automatic) {
  ContentView()
    .environment(AppModel())
}
