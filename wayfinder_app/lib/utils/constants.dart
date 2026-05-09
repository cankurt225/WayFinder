/// Wayfinder — Application constants.
///
/// All tunable parameters for the ML pipeline, audio, and alert system.
/// Backend developers: tweak these values during device testing.
library;

/// ─── ML / Detection ──────────────────────────────────────

/// Default YOLO model identifier.
/// The ultralytics_yolo plugin auto-downloads from official servers.
const String kDefaultModelId = 'yolo26n';

/// Minimum confidence threshold for accepting a detection.
/// Lower = more detections but more false positives.
const double kConfidenceThreshold = 0.55;

/// IoU threshold for Non-Maximum Suppression.
/// The plugin handles NMS internally, but this is used for
/// our own post-filtering when merging temporal detections.
const double kNmsIouThreshold = 0.45;

/// Maximum number of detections to process per frame.
/// Limits CPU/TTS load — we only alert on the N closest objects.
const int kMaxDetectionsPerFrame = 5;

/// ─── Distance Estimation ─────────────────────────────────

/// Default camera focal length in pixels.
/// Calibrate per device using [DeviceProfiler.calibrateFocalLength].
const double kDefaultFocalLength = 500.0;

/// Minimum credible distance in meters.
const double kMinDistance = 0.3;

/// Maximum credible distance in meters.
const double kMaxDistance = 10.0;

/// Known real-world heights of common COCO objects (meters).
const Map<String, double> kKnownObjectHeights = {
  'person': 1.70,
  'bicycle': 1.10,
  'car': 1.50,
  'motorcycle': 1.10,
  'bus': 3.00,
  'truck': 3.50,
  'traffic light': 0.60,
  'fire hydrant': 0.50,
  'stop sign': 0.75,
  'bench': 0.80,
  'cat': 0.30,
  'dog': 0.50,
  'chair': 0.90,
  'couch': 0.85,
  'potted plant': 0.50,
  'dining table': 0.75,
  'toilet': 0.40,
  'tv': 0.50,
  'laptop': 0.25,
  'cell phone': 0.15,
  'book': 0.25,
  'bottle': 0.25,
  'cup': 0.12,
  'door': 2.05,          // Not in COCO but useful
  'stairs': 1.50,        // Not in COCO but useful
  'suitcase': 0.70,
  'backpack': 0.50,
  'umbrella': 1.00,
  'handbag': 0.30,
};

/// Default height for unknown objects (meters).
const double kDefaultObjectHeight = 0.80;

/// ─── Danger Zones ────────────────────────────────────────

/// Distance threshold for [DangerLevel.danger] (meters).
const double kDangerZoneMeters = 1.5;

/// Distance threshold for [DangerLevel.warning] (meters).
const double kWarningZoneMeters = 3.0;

/// Maximum distance for any alert (meters).
/// Objects beyond this are ignored by the alert system.
const double kAlertMaxDistance = 5.0;

/// ─── Voice Guide / TTS ───────────────────────────────────

/// Cooldown between repeated announcements of the same object class (ms).
const int kTtsCooldownMs = 3000;

/// Maximum TTS queue length. Prevents speech backlog.
const int kMaxTtsQueueLength = 3;

/// TTS speech rate (0.0–1.0). Lower = slower.
const double kTtsSpeechRate = 0.55;

/// TTS pitch (0.5–2.0).
const double kTtsPitch = 1.0;

/// Preferred TTS locale.
const String kTtsLocale = 'tr-TR';

/// Fallback TTS locale if primary not available.
const String kTtsFallbackLocale = 'en-US';

/// ─── Spatial Audio ───────────────────────────────────────

/// Alert sound asset path.
const String kAlertSoundAsset = 'assets/sounds/alert_beep.mp3';

/// Minimum volume for distant objects (0.0–1.0).
const double kMinAlertVolume = 0.2;

/// Maximum volume for close objects (0.0–1.0).
const double kMaxAlertVolume = 1.0;

/// Minimum time between spatial audio alerts (ms).
const int kSpatialAudioCooldownMs = 500;

/// ─── Device Profiling ────────────────────────────────────

/// RAM threshold for "entry" device classification (MB).
const int kEntryDeviceRamMb = 3000;

/// RAM threshold for "mid" device classification (MB).
const int kMidDeviceRamMb = 6000;

/// ─── Frame Processing ────────────────────────────────────

/// Frame skip for entry-level devices (process every Nth frame).
const int kEntryFrameSkip = 3;

/// Frame skip for mid-range devices.
const int kMidFrameSkip = 2;

/// Frame skip for flagship devices.
const int kFlagshipFrameSkip = 1;

/// ─── Turkish Labels ──────────────────────────────────────

/// COCO class name → Turkish translation for TTS.
const Map<String, String> kTurkishLabels = {
  'person': 'İnsan',
  'bicycle': 'Bisiklet',
  'car': 'Araba',
  'motorcycle': 'Motosiklet',
  'airplane': 'Uçak',
  'bus': 'Otobüs',
  'train': 'Tren',
  'truck': 'Kamyon',
  'boat': 'Tekne',
  'traffic light': 'Trafik lambası',
  'fire hydrant': 'Yangın musluğu',
  'stop sign': 'Dur işareti',
  'parking meter': 'Park sayacı',
  'bench': 'Bank',
  'bird': 'Kuş',
  'cat': 'Kedi',
  'dog': 'Köpek',
  'horse': 'At',
  'sheep': 'Koyun',
  'cow': 'İnek',
  'elephant': 'Fil',
  'bear': 'Ayı',
  'zebra': 'Zebra',
  'giraffe': 'Zürafa',
  'backpack': 'Sırt çantası',
  'umbrella': 'Şemsiye',
  'handbag': 'El çantası',
  'tie': 'Kravat',
  'suitcase': 'Bavul',
  'frisbee': 'Frizbi',
  'skis': 'Kayak',
  'snowboard': 'Snowboard',
  'sports ball': 'Top',
  'kite': 'Uçurtma',
  'baseball bat': 'Beyzbol sopası',
  'baseball glove': 'Beyzbol eldiveni',
  'skateboard': 'Kaykay',
  'surfboard': 'Sörf tahtası',
  'tennis racket': 'Tenis raketi',
  'bottle': 'Şişe',
  'wine glass': 'Şarap bardağı',
  'cup': 'Bardak',
  'fork': 'Çatal',
  'knife': 'Bıçak',
  'spoon': 'Kaşık',
  'bowl': 'Kase',
  'banana': 'Muz',
  'apple': 'Elma',
  'sandwich': 'Sandviç',
  'orange': 'Portakal',
  'broccoli': 'Brokoli',
  'carrot': 'Havuç',
  'hot dog': 'Sosisli',
  'pizza': 'Pizza',
  'donut': 'Donut',
  'cake': 'Pasta',
  'chair': 'Sandalye',
  'couch': 'Kanepe',
  'potted plant': 'Saksı çiçeği',
  'bed': 'Yatak',
  'dining table': 'Yemek masası',
  'toilet': 'Tuvalet',
  'tv': 'Televizyon',
  'laptop': 'Dizüstü bilgisayar',
  'mouse': 'Fare',
  'remote': 'Kumanda',
  'keyboard': 'Klavye',
  'cell phone': 'Cep telefonu',
  'microwave': 'Mikrodalga',
  'oven': 'Fırın',
  'toaster': 'Tost makinesi',
  'sink': 'Lavabo',
  'refrigerator': 'Buzdolabı',
  'book': 'Kitap',
  'clock': 'Saat',
  'vase': 'Vazo',
  'scissors': 'Makas',
  'teddy bear': 'Oyuncak ayı',
  'hair drier': 'Saç kurutma',
  'toothbrush': 'Diş fırçası',
};
