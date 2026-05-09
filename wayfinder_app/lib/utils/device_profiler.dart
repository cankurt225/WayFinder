/// Wayfinder — Device profiler.
///
/// Detects device capabilities (RAM, GPU support) and selects the
/// optimal inference strategy: frame skip rate, model variant, etc.
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/constants.dart';

/// Device capability tier.
enum DeviceTier {
  /// Low RAM, no GPU delegate → INT8 model, skip frames aggressively.
  entry,

  /// Mid RAM, GPU available → FP16 model, moderate frame skip.
  mid,

  /// High RAM, GPU available → FP16 model, process every frame.
  flagship,
}

/// Profiles the device and provides inference configuration.
class DeviceProfiler {
  DeviceProfiler._();

  static DeviceTier _cachedTier = DeviceTier.mid;
  static bool _initialized = false;

  /// Total device RAM in MB (0 if unknown).
  static int _totalRamMb = 0;

  /// Device model name for logging.
  static String _deviceModel = 'unknown';

  /// Initializes device profiling. Call once at app startup.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';

        // systemMemoryInMB is available on Android
        // Use totalMemory from /proc/meminfo via androidInfo
        _totalRamMb = androidInfo.systemFeatures.isNotEmpty
            ? _estimateRamFromSdk(androidInfo.version.sdkInt)
            : 4000; // Safe default
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceModel = '${iosInfo.name} (${iosInfo.model})';
        _totalRamMb = _estimateIosRam(iosInfo.utsname.machine);
      }

      _cachedTier = _classifyDevice();
      _initialized = true;

      debugPrint('[DeviceProfiler] Device: $_deviceModel');
      debugPrint('[DeviceProfiler] RAM: ${_totalRamMb}MB');
      debugPrint('[DeviceProfiler] Tier: ${_cachedTier.name}');
    } catch (e) {
      debugPrint('[DeviceProfiler] Profiling failed, defaulting to MID: $e');
      _cachedTier = DeviceTier.mid;
      _initialized = true;
    }
  }

  /// Returns the detected device tier.
  static DeviceTier get tier => _cachedTier;

  /// Returns total RAM in MB.
  static int get totalRamMb => _totalRamMb;

  /// Returns device model string.
  static String get deviceModel => _deviceModel;

  /// How many frames to skip between inferences.
  ///
  /// Entry devices: process every 3rd frame
  /// Mid devices: process every 2nd frame
  /// Flagship devices: process every frame
  static int get frameSkipRate {
    switch (_cachedTier) {
      case DeviceTier.entry:
        return kEntryFrameSkip;
      case DeviceTier.mid:
        return kMidFrameSkip;
      case DeviceTier.flagship:
        return kFlagshipFrameSkip;
    }
  }

  /// Recommended confidence threshold per device tier.
  /// Lower-tier devices use higher thresholds to reduce post-processing load.
  static double get recommendedConfidence {
    switch (_cachedTier) {
      case DeviceTier.entry:
        return 0.65; // Stricter → fewer detections → less TTS
      case DeviceTier.mid:
        return 0.55;
      case DeviceTier.flagship:
        return 0.45;
    }
  }

  /// Whether to enable GPU acceleration.
  static bool get useGpuDelegate {
    return _cachedTier != DeviceTier.entry;
  }

  // ─── Private helpers ──────────────────────────────────

  static DeviceTier _classifyDevice() {
    if (_totalRamMb >= kMidDeviceRamMb) {
      return DeviceTier.flagship;
    } else if (_totalRamMb >= kEntryDeviceRamMb) {
      return DeviceTier.mid;
    } else {
      return DeviceTier.entry;
    }
  }

  /// Rough RAM estimate from Android SDK version.
  /// More precise methods require native platform channels.
  static int _estimateRamFromSdk(int sdkInt) {
    if (sdkInt >= 34) return 8000;     // Android 14+ devices
    if (sdkInt >= 31) return 6000;     // Android 12+
    if (sdkInt >= 28) return 4000;     // Android 9+
    return 3000;                        // Older devices
  }

  /// Rough RAM estimate from iOS device identifier.
  static int _estimateIosRam(String machine) {
    // iPhone 15 Pro and later
    if (machine.contains('iPhone16') || machine.contains('iPhone17')) {
      return 8000;
    }
    // iPhone 13/14 range
    if (machine.contains('iPhone14') || machine.contains('iPhone15')) {
      return 6000;
    }
    // Older iPhones
    return 4000;
  }
}
