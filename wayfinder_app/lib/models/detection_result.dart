/// Wayfinder — Detection result model.
///
/// This is the core data structure shared between the ML backend
/// (ObjectDetector / YOLO) and the frontend UI layer. The frontend
/// team consumes [DetectionResult] from [DetectionService.detections] stream.
library;

import 'dart:ui' show Rect, Offset;

/// Direction of a detected object relative to camera center.
enum ObjectDirection {
  left('Sol'),
  center('Orta'),
  right('Sağ');

  const ObjectDirection(this.label);
  final String label;
}

/// Urgency level for proximity alerts.
enum DangerLevel {
  /// > 3 meters — informational only
  safe,

  /// 1.5–3 meters — warn once
  warning,

  /// < 1.5 meters — continuous alert
  danger,
}

/// A single detected object with spatial metadata.
///
/// Produced by [DetectionService], consumed by UI + [VoiceGuide].
class DetectionResult {
  const DetectionResult({
    required this.label,
    required this.className,
    required this.confidence,
    required this.boundingBox,
    this.distance,
    this.direction = ObjectDirection.center,
    this.dangerLevel = DangerLevel.safe,
  });

  /// Human-readable label (e.g. "Sandalye", "İnsan").
  final String label;

  /// Raw COCO class name (e.g. "chair", "person").
  final String className;

  /// Detection confidence 0.0–1.0.
  final double confidence;

  /// Bounding box in normalized coordinates (0.0–1.0).
  ///
  /// Use [boundingBox.left], [boundingBox.top], etc.
  final Rect boundingBox;

  /// Estimated distance in meters. `null` if not yet computed.
  final double? distance;

  /// Horizontal direction relative to camera center.
  final ObjectDirection direction;

  /// How urgently the user should be alerted.
  final DangerLevel dangerLevel;

  // ─── Computed helpers ──────────────────────────────────

  /// Center point of the bounding box (normalized).
  Offset get center => boundingBox.center;

  /// Relative width of the bounding box (0.0–1.0).
  double get relativeWidth => boundingBox.width;

  /// Relative height of the bounding box (0.0–1.0).
  double get relativeHeight => boundingBox.height;

  /// Area of the bounding box (0.0–1.0).
  double get area => boundingBox.width * boundingBox.height;

  /// True if distance is known and object is within danger zone.
  bool get isDangerous =>
      distance != null && distance! < 1.5;

  /// Copy with updated fields.
  DetectionResult copyWith({
    String? label,
    String? className,
    double? confidence,
    Rect? boundingBox,
    double? distance,
    ObjectDirection? direction,
    DangerLevel? dangerLevel,
  }) {
    return DetectionResult(
      label: label ?? this.label,
      className: className ?? this.className,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      distance: distance ?? this.distance,
      direction: direction ?? this.direction,
      dangerLevel: dangerLevel ?? this.dangerLevel,
    );
  }

  @override
  String toString() =>
      'DetectionResult($className, conf=${confidence.toStringAsFixed(2)}, '
      'dist=${distance?.toStringAsFixed(1) ?? "?"}m, ${direction.label})';
}
