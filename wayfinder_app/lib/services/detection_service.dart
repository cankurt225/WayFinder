/// Wayfinder — Detection service.
///
/// Orchestrates the entire ML pipeline:
///   1. Receives raw YOLO results from [YOLOView.onResult]
///   2. Converts to [DetectionResult] with Turkish labels
///   3. Enriches with distance, direction, danger level
///   4. Filters by proximity + confidence
///   5. Publishes to stream for UI + audio consumers
///
/// This is the central backend service. Frontend team consumes
/// [detections] stream, never touches YOLO directly.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../models/detection_result.dart';
import '../services/distance_estimator.dart';
import '../utils/constants.dart';
import '../utils/device_profiler.dart';

/// Pipeline state.
enum PipelineState {
  idle,
  initializing,
  running,
  paused,
  error,
}

class DetectionService extends ChangeNotifier {
  DetectionService({
    DistanceEstimator? distanceEstimator,
  }) : _distanceEstimator = distanceEstimator ?? DistanceEstimator();

  final DistanceEstimator _distanceEstimator;

  // ─── State ────────────────────────────────────────────

  PipelineState _state = PipelineState.idle;
  PipelineState get state => _state;

  List<DetectionResult> _currentDetections = [];
  List<DetectionResult> get currentDetections => _currentDetections;

  final StreamController<List<DetectionResult>> _detectionStreamController =
      StreamController<List<DetectionResult>>.broadcast();

  /// Stream of processed detections. UI + VoiceGuide subscribe here.
  Stream<List<DetectionResult>> get detections =>
      _detectionStreamController.stream;

  // ─── Frame tracking ───────────────────────────────────

  int _frameCount = 0;
  int _processedFrameCount = 0;
  bool _isProcessing = false;
  DateTime? _lastProcessedTime;

  final Queue<DateTime> _frameTimestamps = Queue<DateTime>();

  /// Current FPS of the detection pipeline (sliding window).
  double get effectiveFps {
    if (_frameTimestamps.length < 2) return 0.0;
    
    // Remove timestamps older than 2 seconds
    final now = DateTime.now();
    while (_frameTimestamps.isNotEmpty && now.difference(_frameTimestamps.first).inSeconds > 2) {
      _frameTimestamps.removeFirst();
    }
    
    if (_frameTimestamps.length < 2) return 0.0;
    
    final duration = _frameTimestamps.last.difference(_frameTimestamps.first).inMilliseconds / 1000.0;
    if (duration <= 0) return 0.0;
    
    return (_frameTimestamps.length - 1) / duration;
  }

  DateTime? _startTime;

  /// Image height for distance estimation.
  /// Set by [NavigationScreen] from CameraX preview resolution.
  int _imageHeight = 640;
  set imageHeight(int value) => _imageHeight = value;

  // ─── Lifecycle ────────────────────────────────────────

  /// Initializes the detection pipeline.
  Future<void> initialize() async {
    _state = PipelineState.initializing;
    notifyListeners();

    try {
      await DeviceProfiler.initialize();

      _state = PipelineState.running;
      _startTime = DateTime.now();
      _frameCount = 0;
      _processedFrameCount = 0;
      _frameTimestamps.clear();

      debugPrint('[DetectionService] Pipeline initialized');
      debugPrint('[DetectionService] Device tier: ${DeviceProfiler.tier.name}');
      debugPrint(
          '[DetectionService] Frame skip: ${DeviceProfiler.frameSkipRate}');
      notifyListeners();
    } catch (e) {
      _state = PipelineState.error;
      debugPrint('[DetectionService] Init failed: $e');
      notifyListeners();
    }
  }

  /// Pauses the detection pipeline. Frames will be skipped.
  void pause() {
    _state = PipelineState.paused;
    notifyListeners();
  }

  /// Resumes the detection pipeline.
  void resume() {
    if (_state == PipelineState.paused) {
      _state = PipelineState.running;
      notifyListeners();
    }
  }

  // ─── Core Pipeline ───────────────────────────────────

  /// Called by [YOLOView.onResult] with raw YOLO detections.
  ///
  /// This is the main entry point. The ultralytics_yolo plugin
  /// calls this on every inference frame.
  ///
  /// **Thread safety:** The plugin calls onResult on the platform
  /// thread. This method is designed to be re-entrant safe via
  /// the [_isProcessing] flag.
  void onYoloResults(List<dynamic> results) {
    if (_state != PipelineState.running) return;

    _frameCount++;

    // Frame skip — respect device capability
    if (_frameCount % DeviceProfiler.frameSkipRate != 0) return;

    // Drop frame if previous one is still processing
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      // 1. Convert YOLO plugin results → our DetectionResult model
      final rawDetections = _convertYoloResults(results);

      // 2. Enrich with distance, direction, danger level
      final enriched =
          _distanceEstimator.enrichDetections(rawDetections, _imageHeight);

      // 3. Filter by proximity (only objects within alert range)
      final filtered = _distanceEstimator.filterByProximity(enriched);

      // 4. Update state + publish
      _currentDetections = filtered;
      _detectionStreamController.add(filtered);
      _processedFrameCount++;
      _lastProcessedTime = DateTime.now();
      _frameTimestamps.addLast(_lastProcessedTime!);

      notifyListeners();
    } catch (e) {
      debugPrint('[DetectionService] Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Converts raw YOLO plugin results to [DetectionResult] list.
  ///
  /// The ultralytics_yolo plugin returns platform-specific result
  /// objects. We normalize them into our own model.
  List<DetectionResult> _convertYoloResults(List<dynamic> results) {
    final detections = <DetectionResult>[];

    for (final result in results) {
      try {
        // ultralytics_yolo result properties:
        // - className (String)
        // - confidence (double)
        // - boundingBox.left, .top, .width, .height (normalized 0-1)
        final className = (result.className as String?) ?? 'unknown';
        final confidence = (result.confidence as double?) ?? 0.0;

        if (confidence < DeviceProfiler.recommendedConfidence) continue;

        // Extract normalized bounding box
        final box = result.boundingBox;
        final rect = Rect.fromLTWH(
          (box.left as double?) ?? 0.0,
          (box.top as double?) ?? 0.0,
          (box.width as double?) ?? 0.0,
          (box.height as double?) ?? 0.0,
        );

        // Turkish label lookup
        final turkishLabel =
            kTurkishLabels[className] ?? className;

        detections.add(DetectionResult(
          label: turkishLabel,
          className: className,
          confidence: confidence,
          boundingBox: rect,
        ));
      } catch (e) {
        // Skip malformed results silently
        continue;
      }
    }

    return detections;
  }

  /// Returns a human-readable status string for debugging.
  String get statusReport {
    return '[Pipeline] State: ${_state.name} | '
        'Frames: $_frameCount | '
        'Processed: $_processedFrameCount | '
        'FPS: ${effectiveFps.toStringAsFixed(1)} | '
        'Detections: ${_currentDetections.length} | '
        'Tier: ${DeviceProfiler.tier.name}';
  }

  @override
  void dispose() {
    _detectionStreamController.close();
    super.dispose();
  }
}
