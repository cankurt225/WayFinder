/// Wayfinder — Distance estimator.
///
/// Estimates real-world distance to detected objects using the
/// pinhole camera model: distance = (realHeight × focalLength) / bboxPixelHeight.
///
/// This is a monocular depth estimation heuristic — not ground truth.
/// Accuracy depends on:
///   1. Correct [kKnownObjectHeights] values
///   2. Calibrated [focalLength] for the specific device camera
///   3. Object being roughly upright / perpendicular to camera
library;

import 'dart:ui' show Rect;

import '../models/detection_result.dart';
import '../utils/constants.dart';

class DistanceEstimator {
  /// Creates a distance estimator.
  ///
  /// [focalLength] should ideally be calibrated per device.
  /// Use [kDefaultFocalLength] as starting point, then tune with
  /// real-world measurements.
  DistanceEstimator({
    this.focalLength = kDefaultFocalLength,
  });

  /// Camera focal length in pixels.
  /// Higher = objects appear closer. Calibrate per device.
  final double focalLength;

  /// Estimates distance in meters for a single detection.
  ///
  /// [detection] — the detected object with bounding box.
  /// [imageHeight] — the camera frame height in pixels.
  ///
  /// Returns distance clamped to [kMinDistance]..[kMaxDistance].
  /// Returns `null` if the bounding box height is effectively zero.
  double? estimate(DetectionResult detection, int imageHeight) {
    final bboxHeightNormalized = detection.boundingBox.height;

    // Guard against zero/tiny bboxes that would cause division explosion
    if (bboxHeightNormalized < 0.01) return null;

    final bboxHeightPixels = bboxHeightNormalized * imageHeight;

    // Look up known real-world height, or use default
    final realWorldHeight =
        kKnownObjectHeights[detection.className] ?? kDefaultObjectHeight;

    // Pinhole camera model
    final distance = (realWorldHeight * focalLength) / bboxHeightPixels;

    return distance.clamp(kMinDistance, kMaxDistance);
  }

  /// Estimates distance for a raw bounding box + class name.
  ///
  /// Convenience method when you have bbox data but not a full
  /// [DetectionResult] yet (e.g. during pipeline construction).
  double? estimateFromBbox({
    required String className,
    required Rect bbox,
    required int imageHeight,
  }) {
    final bboxHeightPixels = bbox.height * imageHeight;
    if (bboxHeightPixels < 1.0) return null;

    final realWorldHeight =
        kKnownObjectHeights[className] ?? kDefaultObjectHeight;
    final distance = (realWorldHeight * focalLength) / bboxHeightPixels;

    return distance.clamp(kMinDistance, kMaxDistance);
  }

  /// Determines the [ObjectDirection] from horizontal bbox center.
  ///
  /// Divides the frame into 3 zones:
  ///   - Left:   0.00 – 0.33
  ///   - Center: 0.33 – 0.66
  ///   - Right:  0.66 – 1.00
  static ObjectDirection classifyDirection(Rect bbox) {
    final centerX = bbox.center.dx;
    if (centerX < 0.33) return ObjectDirection.left;
    if (centerX > 0.66) return ObjectDirection.right;
    return ObjectDirection.center;
  }

  /// Determines the [DangerLevel] from estimated distance.
  static DangerLevel classifyDanger(double? distance) {
    if (distance == null) return DangerLevel.safe;
    if (distance < kDangerZoneMeters) return DangerLevel.danger;
    if (distance < kWarningZoneMeters) return DangerLevel.warning;
    return DangerLevel.safe;
  }

  /// Enriches a list of detections with distance, direction, and danger.
  ///
  /// This is the main pipeline method. Call this on raw YOLO output
  /// before passing to [VoiceGuide] or UI.
  List<DetectionResult> enrichDetections(
    List<DetectionResult> rawDetections,
    int imageHeight,
  ) {
    return rawDetections.map((det) {
      final distance = estimate(det, imageHeight);
      final direction = classifyDirection(det.boundingBox);
      final danger = classifyDanger(distance);

      return det.copyWith(
        distance: distance,
        direction: direction,
        dangerLevel: danger,
      );
    }).toList();
  }

  /// Filters and sorts detections by proximity.
  ///
  /// Returns only objects within [kAlertMaxDistance] meters,
  /// sorted closest-first, limited to [kMaxDetectionsPerFrame].
  List<DetectionResult> filterByProximity(List<DetectionResult> detections) {
    final filtered = detections
        .where((d) => d.distance != null && d.distance! <= kAlertMaxDistance)
        .toList()
      ..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

    if (filtered.length > kMaxDetectionsPerFrame) {
      return filtered.sublist(0, kMaxDetectionsPerFrame);
    }
    return filtered;
  }
}
