//
//  DiagnosticsPanel.swift
//  ImageTrackingProviderExploration
//
//  Created by Codex on 09.10.25.
//

import SwiftUI
import ARKit

struct DiagnosticsPanel: View {

  @Environment(AppModel.self) private var appModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Diagnostics")
        .font(.title3)
        .fontWeight(.semibold)

      HStack(alignment: .top, spacing: 24) {
        frameRateSection
          .frame(maxWidth: .infinity, alignment: .leading)

        Divider()

        trackerSection
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if !overlaySummaries.isEmpty {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          Text("Anchors")
            .font(.subheadline)
            .fontWeight(.semibold)

          ForEach(overlaySummaries, id: \.id) { overlay in
            anchorRow(for: overlay)
          }
        }
      }
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.white.opacity(0.08))
    )
    .frame(minWidth: 520)
  }
}

private extension DiagnosticsPanel {

  var overlaySummaries: [MagnetTracker.OverlayState] {
    appModel.magnetTracker.overlays.values
      .sorted { lhs, rhs in
        lhs.referenceName.localizedCaseInsensitiveCompare(rhs.referenceName) == .orderedAscending
      }
  }

  var frameRateSection: some View {
    let stats = appModel.frameRateMonitor.stats

    return VStack(alignment: .leading, spacing: 4) {
      Text("Frame rate")
        .font(.subheadline)
        .fontWeight(.semibold)

      Text(
        """
        \(stats.framesPerSecond, format: .number.precision(.fractionLength(1))) FPS \
        (\(stats.averageFrameTime * 1000, format: .number.precision(.fractionLength(2))) ms)
        """
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      if let lastUpdate = stats.lastUpdate {
        Text("Updated \(lastUpdate.formatted(.relative(presentation: .named)))")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }

  var trackerSection: some View {
    let metrics = appModel.magnetTracker.metrics

    return VStack(alignment: .leading, spacing: 4) {
      Text("Image tracker")
        .font(.subheadline)
        .fontWeight(.semibold)

      Text("Provider: \(metrics.providerState.description)")
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(
        "Active anchors: \(metrics.activelyTrackedAnchors)/\(max(metrics.reportedAnchors, metrics.totalConfigured))"
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      Text("Configured images: \(metrics.totalConfigured)")
        .font(.caption2)
        .foregroundStyle(.tertiary)

      let trackedNames = metrics.trackedReferenceNames
      if trackedNames.isEmpty {
        Text("Tracked references: none")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        Text("Tracked references: \(trackedNames.joined(separator: ", "))")
          .font(.caption2)
          .foregroundStyle(
            trackedNames.count > 1 ? Color.red : Color.green
          )
      }

      if trackedNames.count > 1 {
        Text("Multiple anchors tracked simultaneously.")
          .font(.caption2)
          .foregroundStyle(.red)
      }

      Text(metrics.lastEventDescription)
        .font(.caption2)
        .foregroundStyle(.tertiary)

      if let eventDate = metrics.lastEventDate {
        Text("Last event \(eventDate.formatted(.relative(presentation: .named)))")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }

  func anchorRow(for overlay: MagnetTracker.OverlayState) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(overlay.referenceName)
          .font(.caption)
          .fontWeight(.semibold)
        Spacer()
        Text(overlay.isTracked ? "Tracked" : "Paused")
          .font(.caption2)
          .foregroundStyle(overlay.isTracked ? .green : .orange)
      }

      Text("Scale: \(overlay.estimatedScaleFactor, format: .number.precision(.fractionLength(3)))×")
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text("Updated \(overlay.lastObservationDate.formatted(.relative(presentation: .named)))")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }
}
