//
//  MagnetTracker.swift
//  ImageTrackingProviderExploration
//
//  Created by Codex on 08.10.25.
//

import ARKit
import RealityKit
import SwiftUI

/// Tracks a collection of fridge-magnet reference images and keeps the overlay
/// state needed by SwiftUI and RealityKit in sync.
@MainActor
@Observable
final class MagnetTracker {

  struct MagnetInfo: Equatable {
    let title: String
    let details: String
  }

  struct OverlayState: Identifiable, Equatable {
    let id: UUID
    let referenceName: String
    let info: MagnetInfo
    var transform: Transform
    var isTracked: Bool
    var estimatedScaleFactor: Float
    var lastObservationDate: Date
    var referenceSize: CGSize
  }

  struct TrackingMetrics: Equatable {
    var totalConfigured: Int
    var providerState: DataProviderState
    var reportedAnchors: Int
    var activelyTrackedAnchors: Int
    var trackedReferenceNames: [String]
    var lastEventDescription: String
    var lastEventDate: Date?

    static func idle(totalConfigured: Int) -> TrackingMetrics {
      TrackingMetrics(
        totalConfigured: totalConfigured,
        providerState: .stopped,
        reportedAnchors: 0,
        activelyTrackedAnchors: 0,
        trackedReferenceNames: [],
        lastEventDescription: "Idle",
        lastEventDate: nil
      )
    }
  }

  enum TrackingState: Equatable {
    case idle
    case unsupported
    case loading
    case running
    case failed(String)
  }

  private enum Constants {
    static let resourceGroupName = "FridgeMagnets"
  }

  private let session = ARKitSession()
  private var trackingTask: Task<Void, Never>?
  private var provider: ImageTrackingProvider?
  private static let defaultReferenceInfos: [String: MagnetInfo] = [
    "espresso": MagnetInfo(title: "Espresso Shot", details: "Dial in a double in 25 seconds."),
    "matcha": MagnetInfo(title: "Matcha Mood", details: "Whisk to 70°C and savor slowly."),
    "market": MagnetInfo(title: "Farmer's Harvest", details: "Restock fresh greens every Sunday."),
    "mistery": MagnetInfo(title: "The Green Spurt", details: "Restock fresh greens every future."),
  ]
  private var referenceInfos: [String: MagnetInfo] = MagnetTracker.defaultReferenceInfos
  private var lastLoggedMetricsStamp: Date?

  var overlays: [UUID: OverlayState] = [:]
  var metrics: TrackingMetrics = .idle(totalConfigured: MagnetTracker.defaultReferenceInfos.count)
  var state: TrackingState = .idle
  var statusDescription: String {
    switch state {
    case .idle:
      return "Idle"
    case .unsupported:
      return "Image tracking is not available on this device."
    case .loading:
      return "Loading magnet references…"
    case .running:
      return "Tracking magnets."
    case .failed(let message):
      return "Tracking failed: \(message)"
    }
  }
  var failureReason: String? {
    if case .failed(let message) = state {
      return message
    }
    return nil
  }

  func start() {
    guard trackingTask == nil else { return }
    guard ImageTrackingProvider.isSupported else {
      state = .unsupported
      return
    }

    state = .loading
    trackingTask = Task { [weak self] in
      guard let self else { return }
      await self.runSession()
    }
  }

  func stop() {
    trackingTask?.cancel()
    trackingTask = nil
    session.stop()
    overlays.removeAll()
    provider = nil
    state = .idle
    metrics = TrackingMetrics(
      totalConfigured: referenceInfos.count,
      providerState: .stopped,
      reportedAnchors: 0,
      activelyTrackedAnchors: 0,
      trackedReferenceNames: [],
      lastEventDescription: "Stopped",
      lastEventDate: Date()
    )
  }

  func setReferenceInfo(_ info: MagnetInfo, forName name: String) {
    referenceInfos[name] = info
    metrics.totalConfigured = referenceInfos.count
  }

  func info(forReferenceName name: String) -> MagnetInfo {
    referenceInfos[name] ?? MagnetInfo(
      title: "Magnet \(name)",
      details: "Add details with setReferenceInfo(_:forName:)."
    )
  }

  private func runSession() async {
    defer { trackingTask = nil }

    let referenceImages = ReferenceImage.loadReferenceImages(
      inGroupNamed: Constants.resourceGroupName,
      bundle: .main
    )

    guard !referenceImages.isEmpty else {
      state = .failed("Missing or empty FridgeMagnets.arresourcegroup.")
      return
    }

    let provider = ImageTrackingProvider(referenceImages: referenceImages)
    self.provider = provider

    do {
      try await session.run([provider])
      state = .running
      refreshMetrics(
        providerState: provider.state,
        reportedAnchors: provider.allAnchors.count,
        activelyTracked: overlays.values.filter(\.isTracked).count,
        trackedNames: overlays.values.filter(\.isTracked).map(\.referenceName),
        eventDescription: "Session started",
        eventDate: Date()
      )
      try await handleAnchorUpdates(from: provider)
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  private func handleAnchorUpdates(from provider: ImageTrackingProvider) async throws {
    for await update in provider.anchorUpdates {
      guard !Task.isCancelled else { break }
      let timestamp = Date()

      switch update.event {
      case .added, .updated:
        apply(update.anchor, timestamp: timestamp)
        refreshMetrics(
          providerState: provider.state,
          reportedAnchors: provider.allAnchors.count,
          activelyTracked: overlays.values.filter(\.isTracked).count,
          trackedNames: overlays.values.filter(\.isTracked).map(\.referenceName),
          eventDescription: describe(event: update.event),
          eventDate: timestamp
        )
      case .removed:
        overlays.removeValue(forKey: update.anchor.id)
        refreshMetrics(
          providerState: provider.state,
          reportedAnchors: provider.allAnchors.count,
          activelyTracked: overlays.values.filter(\.isTracked).count,
          trackedNames: overlays.values.filter(\.isTracked).map(\.referenceName),
          eventDescription: describe(event: update.event),
          eventDate: timestamp
        )
      @unknown default:
        refreshMetrics(
          providerState: provider.state,
          reportedAnchors: provider.allAnchors.count,
          activelyTracked: overlays.values.filter(\.isTracked).count,
          trackedNames: overlays.values.filter(\.isTracked).map(\.referenceName),
          eventDescription: "Unknown event",
          eventDate: timestamp
        )
      }
    }
  }

  private func apply(_ anchor: ImageAnchor, timestamp: Date) {
    guard let referenceName = anchor.referenceImage.name else { return }

    let transform = Transform(matrix: anchor.originFromAnchorTransform)
    let referenceSize = anchor.referenceImage.physicalSize
    let info = info(forReferenceName: referenceName)
    let state = OverlayState(
      id: anchor.id,
      referenceName: referenceName,
      info: info,
      transform: transform,
      isTracked: anchor.isTracked,
      estimatedScaleFactor: anchor.estimatedScaleFactor,
      lastObservationDate: timestamp,
      referenceSize: referenceSize
    )

    overlays[anchor.id] = state
#if DEBUG
    logOverlayUpdate(state)
#endif
  }

  private func refreshMetrics(
    providerState: DataProviderState,
    reportedAnchors: Int,
    activelyTracked: Int,
    trackedNames: [String],
    eventDescription: String,
    eventDate: Date
  ) {
    metrics = TrackingMetrics(
      totalConfigured: referenceInfos.count,
      providerState: providerState,
      reportedAnchors: reportedAnchors,
      activelyTrackedAnchors: activelyTracked,
      trackedReferenceNames: trackedNames.sorted(),
      lastEventDescription: eventDescription,
      lastEventDate: eventDate
    )
#if DEBUG
    logMetricsUpdate(metrics)
#endif
  }

  private func describe(
    event: AnchorUpdate<ImageAnchor>.Event
  ) -> String {
    switch event {
    case .added:
      return "Anchor added"
    case .updated:
      return "Anchor updated"
    case .removed:
      return "Anchor removed"
    @unknown default:
      return "Unknown anchor event"
    }
  }

#if DEBUG
  private func logOverlayUpdate(_ overlay: OverlayState) {
    print(
      """
      [MagnetTracker] Anchor \(overlay.referenceName) \(overlay.id) \
      tracked=\(overlay.isTracked) scale=\(overlay.estimatedScaleFactor) \
      updated=\(overlay.lastObservationDate)
      """
    )
  }

  private func logMetricsUpdate(_ metrics: TrackingMetrics) {
    guard metrics.lastEventDate != lastLoggedMetricsStamp else { return }
    lastLoggedMetricsStamp = metrics.lastEventDate
    print(
      """
      [MagnetTracker] provider=\(metrics.providerState) configured=\(metrics.totalConfigured) \
      reported=\(metrics.reportedAnchors) active=\(metrics.activelyTrackedAnchors) \
      tracked=\(metrics.trackedReferenceNames.joined(separator: ", ")) \
      lastEvent='\(metrics.lastEventDescription)' at=\(metrics.lastEventDate?.description ?? "n/a")
      """
    )
  }
#endif
}
