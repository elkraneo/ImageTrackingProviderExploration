## Image Tracking Diagnostics

This project explores the field limits of `ImageTrackingProvider` on visionOS 26.  
The working thesis is that ARKit can prioritise at most one reference image at a time, favouring the anchor with the highest confidence and yielding a comparatively low update cadence when multiple images compete for attention. The codebase now instruments the runtime so you can collect quantitative evidence for this behaviour.

### What is instrumented

- **Per-anchor telemetry** – every `ImageAnchor` update records whether ARKit currently tracks the reference image, the estimated scale factor, and the timestamp of the last observation. This state drives both the individual overlay cards and the diagnostics HUD.
- **Provider-level metrics** – the tracker aggregates:
  - `ImageTrackingProvider.state`
  - number of configured reference images
  - number of anchors reported by the provider
  - number of anchors actively tracked (`isTracked == true`)
  - a short description and timestamp for the most recent anchor event (`added`, `updated`, `removed`)
- **Frame cadence** – a `CADisplayLink`-backed `FrameRateMonitor` estimates frames-per-second and average frame time from a rolling window of samples (up to 120 frames) to quantify the low-frequency updates seen when multiple markers are visible.

All mutable state is `@Observable` on the main actor, so both SwiftUI and RealityView stay in sync without violating the project’s threading constraints.

### How to gather evidence

1. **Populate reference images**  
   Add each marker you plan to test to `FridgeMagnets.arresourcegroup` in the Reality Composer Pro bundle, matching the names listed in `MagnetTracker.referenceInfos`.

2. **Run the immersive space**  
   Build the `ImageTrackingProviderExploration` target for Apple Vision Pro and open the immersive space using the in-app button.

3. **Observe the diagnostics panel**  
   While the immersive content is visible, a diagnostics overlay appears in the top-left corner, summarising frame rate and tracking metrics in real time. The per-anchor cards in spatial space mirror the same data at each marker’s world-aligned position.

4. **Introduce multiple markers**  
   Bring two or more physical markers into the camera view. Watch for:
   - Only one anchor being “Tracked” at a time (others show “Paused”) even though their overlays retain the last pose.
   - Frame rate dropping or oscillating in the diagnostics panel as ARKit alternates priorities.
   - Event descriptions recording rapid `updated`/`removed` cycles corresponding to the provider switching focus.

5. **Capture artefacts**  
   Record screen video or take sequential screenshots highlighting the diagnostics HUD numbers while multiple markers are present. Note the timestamps and FPS to support the thesis in your report.

### Extending the investigation

- Adjust the size or physical spacing of markers to see how often ARKit swaps focus.
- Compare behaviour across lighting conditions to check if confidence (implied by `isTracked`) correlates with the chosen anchor.
- Export the rolling metrics by hooking into `MagnetTracker.metrics` if you need structured logs for offline analysis.

With these diagnostics in place you can demonstrate, in situ, how `ImageTrackingProvider` deprioritises secondary markers and how that impacts realtime responsiveness.
