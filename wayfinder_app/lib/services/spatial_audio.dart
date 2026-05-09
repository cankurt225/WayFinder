/// Wayfinder — Spatial audio.
///
/// Plays directional alert sounds that give the user a sense of
/// WHERE the obstacle is:
///   - Left/right panning based on bbox horizontal position
///   - Volume scaling based on distance (closer = louder)
///   - Rapid beeping for danger-level proximity
///
/// Works alongside [VoiceGuide] — spatial audio is the "beep",
/// TTS is the "description".
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../models/detection_result.dart';
import '../utils/constants.dart';

/// Spatial audio + haptic alert service.
class SpatialAudio {
  SpatialAudio();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  DateTime _lastAlertTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the device supports vibration.
  bool _hasVibrator = false;

  /// Subscription to detection stream.
  StreamSubscription<List<DetectionResult>>? _subscription;

  // ─── Lifecycle ────────────────────────────────────────

  /// Initializes audio player and haptic engine.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Pre-load alert sound
      await _player.setSource(AssetSource('sounds/alert_beep.mp3'));
      await _player.setReleaseMode(ReleaseMode.stop);

      // Check vibration support
      _hasVibrator = await Vibration.hasVibrator() ?? false;

      _initialized = true;
      debugPrint('[SpatialAudio] Initialized (vibrator: $_hasVibrator)');
    } catch (e) {
      debugPrint('[SpatialAudio] Init failed: $e');
      // Non-fatal — app works without audio alerts
      _initialized = true;
    }
  }

  /// Subscribes to detection stream from [DetectionService].
  void listenTo(Stream<List<DetectionResult>> detectionStream) {
    _subscription?.cancel();
    _subscription = detectionStream.listen(_onDetections);
  }

  /// Releases resources.
  Future<void> dispose() async {
    _subscription?.cancel();
    await _player.dispose();
  }

  // ─── Detection Handler ────────────────────────────────

  /// Called when new detections arrive.
  /// Plays spatial alert for the closest dangerous object.
  void _onDetections(List<DetectionResult> detections) {
    if (!_initialized || detections.isEmpty) return;

    // Find the most dangerous (closest) detection
    final closest = detections.first; // Already sorted by distance

    if (closest.distance == null) return;
    if (closest.distance! > kAlertMaxDistance) return;

    // Cooldown — don't spam audio
    final now = DateTime.now();
    final cooldownMs = _getCooldownForDanger(closest.dangerLevel);
    if (now.difference(_lastAlertTime).inMilliseconds < cooldownMs) return;

    _lastAlertTime = now;

    // Play alert with spatial positioning
    _playDirectionalAlert(closest);

    // Haptic feedback for danger zone
    if (closest.dangerLevel == DangerLevel.danger) {
      _triggerHaptic(closest);
    }
  }

  /// Plays an alert sound with left/right panning and volume
  /// proportional to distance.
  Future<void> _playDirectionalAlert(DetectionResult detection) async {
    try {
      // Volume: inversely proportional to distance
      // Close (0.5m) → 1.0, Far (5m) → 0.2
      final distance = detection.distance ?? kAlertMaxDistance;
      final normalizedDistance =
          ((distance - kMinDistance) / (kAlertMaxDistance - kMinDistance))
              .clamp(0.0, 1.0);
      final volume =
          kMaxAlertVolume - (normalizedDistance * (kMaxAlertVolume - kMinAlertVolume));

      await _player.setVolume(volume);

      // Stereo panning: bbox center X → -1.0 (left) to +1.0 (right)
      // Normalized bbox center: 0.0 = left edge, 1.0 = right edge
      final pan = (detection.center.dx * 2.0 - 1.0).clamp(-1.0, 1.0);
      await _player.setBalance(pan);

      // Playback speed: faster beep for closer objects
      final rate = detection.dangerLevel == DangerLevel.danger ? 1.5 : 1.0;
      await _player.setPlaybackRate(rate);

      // Play
      await _player.stop();
      await _player.play(AssetSource('sounds/alert_beep.mp3'));
    } catch (e) {
      debugPrint('[SpatialAudio] Play error: $e');
    }
  }

  /// Triggers haptic feedback scaled to danger level.
  Future<void> _triggerHaptic(DetectionResult detection) async {
    if (!_hasVibrator) return;

    try {
      switch (detection.dangerLevel) {
        case DangerLevel.danger:
          // Strong double-pulse vibration
          await Vibration.vibrate(
            pattern: [0, 100, 50, 100],
            intensities: [0, 255, 0, 255],
          );
          break;
        case DangerLevel.warning:
          // Single short pulse
          await Vibration.vibrate(duration: 50, amplitude: 128);
          break;
        case DangerLevel.safe:
          break; // No haptic for safe objects
      }
    } catch (e) {
      debugPrint('[SpatialAudio] Haptic error: $e');
    }
  }

  /// Returns cooldown in ms based on danger level.
  /// Closer = more frequent alerts.
  int _getCooldownForDanger(DangerLevel level) {
    switch (level) {
      case DangerLevel.danger:
        return 300; // Rapid alerts
      case DangerLevel.warning:
        return kSpatialAudioCooldownMs;
      case DangerLevel.safe:
        return 2000; // Infrequent
    }
  }
}
