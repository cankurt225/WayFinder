import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Tek bir tespit sonucunu temsil eder.
class DetectionResult {
  final double x; // sol üst köşe x (0-1 normalize)
  final double y; // sol üst köşe y (0-1 normalize)
  final double width; // genişlik (0-1 normalize)
  final double height; // yükseklik (0-1 normalize)
  final String label;
  final double confidence;
  final int classIndex;

  DetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.confidence,
    required this.classIndex,
  });

  @override
  String toString() =>
      'DetectionResult(label: $label, conf: ${confidence.toStringAsFixed(2)}, '
      'x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, '
      'w: ${width.toStringAsFixed(3)}, h: ${height.toStringAsFixed(3)})';
}

/// YOLOv8n TFLite modelini yükler ve kamera frame'leri üzerinde
/// gerçek zamanlı nesne tespiti yapar.
class YoloDetector {
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.45;
  static const double iouThreshold = 0.5;
  static const int numClasses = 80;

  Interpreter? _interpreter;
  bool _isDetecting = false;

  bool get isReady => _interpreter != null;
  bool get isBusy => _isDetecting;

  /// Modeli asset'ten yükler.
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/yolov8n_float32.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      // Model giriş/çıkış bilgilerini logla
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      debugPrint('YOLO Model yüklendi!');
      debugPrint('  Input shape: ${inputTensor.shape}, type: ${inputTensor.type}');
      debugPrint('  Output shape: ${outputTensor.shape}, type: ${outputTensor.type}');
    } catch (e) {
      debugPrint('YOLO model yüklenemedi: $e');
      rethrow;
    }
  }

  /// Kamera frame'i üzerinde YOLO tespiti çalıştırır.
  /// [cameraImage]: Kameradan gelen YUV420 formatında görüntü.
  /// [imageRotation]: Kamera sensör rotasyonu (derece).
  Future<List<DetectionResult>> detect(
    CameraImage cameraImage, {
    int imageRotation = 90,
  }) async {
    if (_interpreter == null || _isDetecting) return [];

    _isDetecting = true;
    try {
      // 1. Preprocess: CameraImage → float32 input tensor
      final input = _preprocessCameraImage(cameraImage, imageRotation);

      // 2. Output buffer: [1, 84, 8400]
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputSize = outputShape.reduce((a, b) => a * b);
      final outputBuffer = Float32List(outputSize);
      final output = outputBuffer.buffer.asFloat32List();

      // Reshape for interpreter
      final outputMap = <int, Object>{
        0: output.reshape(outputShape),
      };

      // 3. Inference
      _interpreter!.runForMultipleInputs([input], outputMap);

      // 4. Postprocess: NMS + filter
      final results = _postprocess(output, outputShape);
      return results;
    } catch (e) {
      debugPrint('YOLO detection hatası: $e');
      return [];
    } finally {
      _isDetecting = false;
    }
  }

  /// YUV420 CameraImage'ı 640×640 float32 RGB input tensor'a dönüştürür.
  List<List<List<List<double>>>> _preprocessCameraImage(
    CameraImage image,
    int rotation,
  ) {
    final int imgWidth = image.width;
    final int imgHeight = image.height;

    // YUV420 plane'lerini al
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    // Ölçekleme faktörleri (aspect ratio koruyarak)
    // Kamera görüntüsünü 640×640'a sığdırmak için
    final double scaleX = imgWidth / inputSize;
    final double scaleY = imgHeight / inputSize;

    // Input tensor: [1, 640, 640, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            // Hedef pikselin kaynak görüntüdeki konumu
            int srcX, srcY;

            if (rotation == 90) {
              // 90 derece döndürme (portre modu)
              srcX = (y * scaleY).toInt().clamp(0, imgWidth - 1);
              srcY = ((inputSize - 1 - x) * scaleX).toInt().clamp(0, imgHeight - 1);
            } else if (rotation == 270) {
              srcX = ((inputSize - 1 - y) * scaleY).toInt().clamp(0, imgWidth - 1);
              srcY = (x * scaleX).toInt().clamp(0, imgHeight - 1);
            } else {
              srcX = (x * scaleX).toInt().clamp(0, imgWidth - 1);
              srcY = (y * scaleY).toInt().clamp(0, imgHeight - 1);
            }

            // YUV → RGB dönüşümü
            final int yIndex = srcY * yRowStride + srcX;
            final int uvIndex =
                (srcY ~/ 2) * uvRowStride + (srcX ~/ 2) * uvPixelStride;

            final int yVal = yPlane[yIndex];
            final int uVal = uPlane[uvIndex.clamp(0, uPlane.length - 1)];
            final int vVal = vPlane[uvIndex.clamp(0, vPlane.length - 1)];

            // YUV → RGB
            int r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
            int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128))
                .round()
                .clamp(0, 255);
            int b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);

            // Normalize: [0, 255] → [0.0, 1.0]
            return [r / 255.0, g / 255.0, b / 255.0];
          },
        ),
      ),
    );

    return input;
  }

  /// Model çıktısını işler: transpose, threshold, NMS uygular.
  /// YOLOv8 output: [1, 84, 8400]
  /// - 84 = 4 (cx, cy, w, h) + 80 (class scores)
  /// - 8400 = toplam detection sayısı
  List<DetectionResult> _postprocess(Float32List output, List<int> shape) {
    // shape: [1, 84, 8400]
    final int numDetections = shape[2]; // 8400
    final int numValues = shape[1]; // 84

    // Tüm tespitleri topla
    final List<_RawDetection> rawDetections = [];

    for (int i = 0; i < numDetections; i++) {
      // Bounding box değerleri (center format, 0-640 aralığında)
      final double cx = output[0 * numDetections + i]; // center x
      final double cy = output[1 * numDetections + i]; // center y
      final double w = output[2 * numDetections + i]; // width
      final double h = output[3 * numDetections + i]; // height

      // En yüksek sınıf skorunu bul
      double maxScore = 0;
      int maxClassIdx = 0;
      for (int c = 0; c < numClasses; c++) {
        final double score = output[(4 + c) * numDetections + i];
        if (score > maxScore) {
          maxScore = score;
          maxClassIdx = c;
        }
      }

      // Confidence threshold kontrolü
      if (maxScore < confidenceThreshold) continue;

      // Center format → top-left format & normalize (0-1)
      final double x1 = (cx - w / 2) / inputSize;
      final double y1 = (cy - h / 2) / inputSize;
      final double bw = w / inputSize;
      final double bh = h / inputSize;

      rawDetections.add(_RawDetection(
        x: x1.clamp(0.0, 1.0),
        y: y1.clamp(0.0, 1.0),
        width: bw.clamp(0.0, 1.0),
        height: bh.clamp(0.0, 1.0),
        confidence: maxScore,
        classIndex: maxClassIdx,
      ));
    }

    // NMS uygula
    final nmsResults = _nms(rawDetections);

    // DetectionResult'lara dönüştür
    return nmsResults
        .map((d) => DetectionResult(
              x: d.x,
              y: d.y,
              width: d.width,
              height: d.height,
              label: cocoLabels[d.classIndex],
              confidence: d.confidence,
              classIndex: d.classIndex,
            ))
        .toList();
  }

  /// Non-Maximum Suppression (NMS) uygular.
  List<_RawDetection> _nms(List<_RawDetection> detections) {
    if (detections.isEmpty) return [];

    // Sınıfa göre grupla
    final Map<int, List<_RawDetection>> classDetections = {};
    for (final d in detections) {
      classDetections.putIfAbsent(d.classIndex, () => []).add(d);
    }

    final List<_RawDetection> results = [];

    for (final entry in classDetections.entries) {
      final dets = entry.value;
      // Confidence'a göre azalan sırala
      dets.sort((a, b) => b.confidence.compareTo(a.confidence));

      final List<bool> suppressed = List.filled(dets.length, false);

      for (int i = 0; i < dets.length; i++) {
        if (suppressed[i]) continue;
        results.add(dets[i]);

        for (int j = i + 1; j < dets.length; j++) {
          if (suppressed[j]) continue;
          if (_calculateIoU(dets[i], dets[j]) > iouThreshold) {
            suppressed[j] = true;
          }
        }
      }
    }

    return results;
  }

  /// İki bounding box arasındaki IoU (Intersection over Union) değerini hesaplar.
  double _calculateIoU(_RawDetection a, _RawDetection b) {
    final double x1 = max(a.x, b.x);
    final double y1 = max(a.y, b.y);
    final double x2 = min(a.x + a.width, b.x + b.width);
    final double y2 = min(a.y + a.height, b.y + b.height);

    if (x2 <= x1 || y2 <= y1) return 0.0;

    final double intersection = (x2 - x1) * (y2 - y1);
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double union = areaA + areaB - intersection;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Kaynakları serbest bırakır.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  // ─── COCO 80 Sınıf Etiketleri ───────────────────────────────────────
  static const List<String> cocoLabels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
    'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
    'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag',
    'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite',
    'baseball bat', 'baseball glove', 'skateboard', 'surfboard',
    'tennis racket', 'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon',
    'bowl', 'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
    'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant',
    'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
    'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
    'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear',
    'hair drier', 'toothbrush',
  ];
}

/// NMS için kullanılan dahili tespit yapısı.
class _RawDetection {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final int classIndex;

  _RawDetection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.classIndex,
  });
}
