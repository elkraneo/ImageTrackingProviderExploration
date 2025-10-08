//
//  MagnetOverlayView.swift
//  ImageTrackingProviderExploration
//
//  Created by Codex on 08.10.25.
//

import RealityKit
import SwiftUI

struct MagnetOverlayView: View {

  let state: MagnetTracker.OverlayState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(state.info.title)
        .font(.headline)
      Text(state.info.details)
        .font(.callout)
        .foregroundStyle(.secondary)

      if !state.isTracked {
        Text("Searching…")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(.ultraThinMaterial)
        .shadow(radius: 12)
    )
    .frame(maxWidth: 220, alignment: .leading)
  }
}

#Preview {
  MagnetOverlayView(
    state: .init(
      id: .init(),
      referenceName: "espresso",
      info: .init(
        title: "Espresso Shot",
        details: "Dial in a double in 25 seconds."
      ),
      transform: .identity,
      isTracked: true
    )
  )
  .padding()
}
