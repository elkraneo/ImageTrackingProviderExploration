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
    static let verticalOffset: Float = 0.04
  }

  private let session = ARKitSession()
  private var trackingTask: Task<Void, Never>?
  private var provider: ImageTrackingProvider?
  private var referenceInfos: [String: MagnetInfo] = [
    "espresso": MagnetInfo(title: "Espresso Shot", details: "Dial in a double in 25 seconds."),
    "matcha": MagnetInfo(title: "Matcha Mood", details: "Whisk to 70°C and savor slowly."),
    "market": MagnetInfo(title: "Farmer's Harvest", details: "Restock fresh greens every Sunday."),
  ]

  var overlays: [UUID: OverlayState] = [:]
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
  }

  func setReferenceInfo(_ info: MagnetInfo, forName name: String) {
    referenceInfos[name] = info
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
      try await handleAnchorUpdates(from: provider)
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  private func handleAnchorUpdates(from provider: ImageTrackingProvider) async throws {
    for await update in provider.anchorUpdates {
      guard !Task.isCancelled else { break }

      switch update.event {
      case .added, .updated:
        apply(update.anchor)
      case .removed:
        overlays.removeValue(forKey: update.anchor.id)
      @unknown default:
        break
      }
    }
  }

  private func apply(_ anchor: ImageAnchor) {
    guard let referenceName = anchor.referenceImage.name else { return }

    // Keep the last known pose so overlays remain visible if ARKit drops tracking while
    // another image is prioritised.
    var transform = Transform(matrix: anchor.originFromAnchorTransform)
    transform.translation.y += Constants.verticalOffset

    let info = info(forReferenceName: referenceName)
    let state = OverlayState(
      id: anchor.id,
      referenceName: referenceName,
      info: info,
      transform: transform,
      isTracked: anchor.isTracked
    )

    overlays[anchor.id] = state
  }
}
