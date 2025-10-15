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

      statusLabel

      Text(state.info.details)
        .font(.callout)
        .foregroundStyle(.secondary)

      metricsStack
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
      isTracked: true,
      estimatedScaleFactor: 1.02,
      lastObservationDate: .now,
      referenceSize: CGSize(width: 0.08, height: 0.05)
    )
  )
  .padding()
}

private extension MagnetOverlayView {

  var statusLabel: some View {
    Label {
      Text(state.isTracked ? "Tracked" : "Not tracked")
    } icon: {
      Image(
        systemName: state.isTracked ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
      )
      .symbolRenderingMode(.palette)
      .foregroundStyle(state.isTracked ? .green : .orange, .white)
    }
    .font(.caption)
    .fontWeight(.semibold)
  }

  var metricsStack: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Scale: \(state.estimatedScaleFactor, format: .number.precision(.fractionLength(3)))×")
        .font(.caption)
        .foregroundStyle(.secondary)

      Text("Updated: \(state.lastObservationDate, format: .dateTime.hour().minute().second())")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
}
