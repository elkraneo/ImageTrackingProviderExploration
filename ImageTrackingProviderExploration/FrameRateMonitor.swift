//
//  FrameRateMonitor.swift
//  ImageTrackingProviderExploration
//
//  Created by Codex on 09.10.25.
//

import Foundation
import QuartzCore

@MainActor
@Observable
final class FrameRateMonitor: NSObject {

  struct Stats: Equatable {
    var framesPerSecond: Double
    var averageFrameTime: Double
    var sampleCount: Int
    var lastUpdate: Date?

    static let idle = Stats(framesPerSecond: 0, averageFrameTime: 0, sampleCount: 0, lastUpdate: nil)
  }

  private let maxSamples = 120
  private var displayLink: CADisplayLink?
  private var lastTimestamp: CFTimeInterval?
  private var frameIntervals: [Double] = []
  private var lastLog: Date?

  var stats: Stats = .idle

  func start() {
    guard displayLink == nil else { return }

    let link = CADisplayLink(target: self, selector: #selector(step(_:)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 90)
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  func stop() {
    displayLink?.invalidate()
    displayLink = nil
    lastTimestamp = nil
    frameIntervals.removeAll()
    stats = .idle
  }

  @objc
  private func step(_ link: CADisplayLink) {
    let timestamp = link.timestamp

    if let lastTimestamp {
      let delta = timestamp - lastTimestamp
      guard delta > 0 else { return }

      frameIntervals.append(delta)
      if frameIntervals.count > maxSamples {
        frameIntervals.removeFirst(frameIntervals.count - maxSamples)
      }

      let totalDuration = frameIntervals.reduce(0, +)
      let average = totalDuration / Double(frameIntervals.count)
      let fps = average > 0 ? 1.0 / average : 0

      stats = Stats(
        framesPerSecond: fps,
        averageFrameTime: average,
        sampleCount: frameIntervals.count,
        lastUpdate: Date()
      )
#if DEBUG
      logStatsIfNeeded()
#endif
    }

    self.lastTimestamp = timestamp
  }

#if DEBUG
  private func logStatsIfNeeded() {
    let now = Date()
    guard lastLog == nil || now.timeIntervalSince(lastLog!) > 2 else { return }
    lastLog = now
    print(
      "[FrameRateMonitor] fps=\(stats.framesPerSecond) "
        + "avgFrameMs=\(stats.averageFrameTime * 1000) samples=\(stats.sampleCount)"
    )
  }
#endif
}
