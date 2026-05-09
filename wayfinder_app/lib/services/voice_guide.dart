/// Wayfinder — Voice guide (TTS).
///
/// Converts [DetectionResult] detections into spoken Turkish alerts.
/// Features:
///   - Cooldown per object class (no "Sandalye" spam)
///   - Priority queue: closest objects announced first
///   - Directional context: "Solda 2 metre sandalye"
///   - Danger-level escalation: danger objects interrupt queue
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/detection_result.dart';
import '../utils/constants.dart';

/// Voice guide service for spoken navigation alerts.
class VoiceGuide {
  VoiceGuide();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  /// Tracks last announcement time per object class.
  /// Key: className, Value: timestamp ms
  final Map<String, int> _cooldownMap = {};

  /// Speech queue — FIFO with max length.
  final Queue<_SpeechItem> _speechQueue = Queue<_SpeechItem>();

  /// Subscription to detection stream.
  StreamSubscription<List<DetectionResult>>? _subscription;

  // ─── Lifecycle ────────────────────────────────────────

  /// Initializes TTS engine with Turkish locale.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check if Turkish is available, fallback to English
      final languages = await _tts.getLanguages;
      final hasTurkish = (languages as List).any(
        (lang) => lang.toString().toLowerCase().contains('tr'),
      );

      if (hasTurkish) {
        await _tts.setLanguage(kTtsLocale);
        debugPrint('[VoiceGuide] Using Turkish TTS');
      } else {
        await _tts.setLanguage(kTtsFallbackLocale);
        debugPrint('[VoiceGuide] Turkish unavailable, using English');
      }

      await _tts.setSpeechRate(kTtsSpeechRate);
      await _tts.setPitch(kTtsPitch);
      await _tts.setVolume(1.0);

      // Track speaking state
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _processQueue();
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[VoiceGuide] TTS error: $msg');
        _isSpeaking = false;
      });

      _initialized = true;
      debugPrint('[VoiceGuide] Initialized');
    } catch (e) {
      debugPrint('[VoiceGuide] Init failed: $e');
    }
  }

  /// Subscribes to detection stream from [DetectionService].
  void listenTo(Stream<List<DetectionResult>> detectionStream) {
    _subscription?.cancel();
    _subscription = detectionStream.listen(_onDetections);
  }

  /// Stops TTS and cancels subscriptions.
  Future<void> dispose() async {
    _subscription?.cancel();
    await _tts.stop();
    _speechQueue.clear();
    _cooldownMap.clear();
  }

  // ─── Detection Handler ────────────────────────────────

  /// Called when new detections arrive from the pipeline.
  void _onDetections(List<DetectionResult> detections) {
    if (!_initialized || detections.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Sort by distance (closest first) — these get priority
    final sorted = List<DetectionResult>.from(detections)
      ..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

    for (final detection in sorted) {
      // Check cooldown — don't repeat same class too quickly
      final lastAnnounced = _cooldownMap[detection.className];
      if (lastAnnounced != null &&
          (now - lastAnnounced) < kTtsCooldownMs) {
        continue;
      }

      // Build speech text
      final speechText = _buildSpeechText(detection);
      if (speechText == null) continue;

      // Danger objects get priority (inserted at front)
      final item = _SpeechItem(
        text: speechText,
        className: detection.className,
        priority: detection.dangerLevel == DangerLevel.danger ? 0 : 1,
      );

      if (detection.dangerLevel == DangerLevel.danger) {
        // Interrupt current speech for danger alerts
        _tts.stop();
        _isSpeaking = false;
        _speechQueue.addFirst(item);
      } else if (_speechQueue.length < kMaxTtsQueueLength) {
        _speechQueue.addLast(item);
      }

      // Mark as announced
      _cooldownMap[detection.className] = now;
    }

    _processQueue();
  }

  /// Builds Turkish speech text for a detection.
  ///
  /// Format examples:
  ///   - "Dikkat! Solda 1 metre insan"
  ///   - "Sağda 3 metre sandalye"
  ///   - "Önde araba"
  String? _buildSpeechText(DetectionResult detection) {
    if (detection.distance == null) return null;

    final label = detection.label;
    final distMeters = detection.distance!.round();
    final direction = detection.direction;

    final buffer = StringBuffer();

    // Danger prefix
    if (detection.dangerLevel == DangerLevel.danger) {
      buffer.write('Dikkat! ');
    }

    // Direction
    switch (direction) {
      case ObjectDirection.left:
        buffer.write('Solda ');
        break;
      case ObjectDirection.center:
        buffer.write('Önde ');
        break;
      case ObjectDirection.right:
        buffer.write('Sağda ');
        break;
    }

    // Distance
    if (distMeters <= 1) {
      buffer.write('çok yakın ');
    } else {
      buffer.write('$distMeters metre ');
    }

    // Object
    buffer.write(label.toLowerCase());

    return buffer.toString();
  }

  /// Processes the speech queue.
  Future<void> _processQueue() async {
    if (_isSpeaking || _speechQueue.isEmpty) return;

    final item = _speechQueue.removeFirst();
    _isSpeaking = true;

    try {
      await _tts.speak(item.text);
    } catch (e) {
      debugPrint('[VoiceGuide] Speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Immediately speaks a custom message (e.g. "Uygulama başlatıldı").
  Future<void> speakImmediate(String text) async {
    if (!_initialized) return;
    await _tts.stop();
    _isSpeaking = true;
    _speechQueue.clear();
    await _tts.speak(text);
  }

  /// Stops all speech immediately.
  Future<void> stop() async {
    await _tts.stop();
    _speechQueue.clear();
    _isSpeaking = false;
  }
}

/// Internal speech queue item.
class _SpeechItem {
  const _SpeechItem({
    required this.text,
    required this.className,
    required this.priority,
  });

  final String text;
  final String className;

  /// 0 = highest priority (danger), 1 = normal
  final int priority;
}
