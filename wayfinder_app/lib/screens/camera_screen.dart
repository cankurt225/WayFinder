import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/yolo_detector.dart';
import '../widgets/detection_overlay.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _selectedCameraIndex = 0;

  // ── YOLO Detection ────────────────────────────────────────────
  final YoloDetector _detector = YoloDetector();
  List<DetectionResult> _detections = [];
  bool _isModelLoaded = false;
  bool _isStreaming = false;
  int _frameCount = 0;
  static const int _frameSkip = 3; // Her 3 frame'de 1 inference

  // FPS hesaplama
  final Stopwatch _fpsStopwatch = Stopwatch();
  double _fps = 0;
  int _fpsFrameCount = 0;
  double _inferenceMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera(_selectedCameraIndex);
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _detector.loadModel();
      if (mounted) {
        setState(() => _isModelLoaded = true);
        debugPrint('YOLO modeli başarıyla yüklendi');
      }
    } catch (e) {
      debugPrint('Model yüklenemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('YOLO modeli yüklenemedi: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _initCamera(int cameraIndex) {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.medium, // Performans için medium
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted && _isModelLoaded) {
        _startDetection();
      }
    });
    if (mounted) setState(() {});
  }

  /// Kamera stream'ini başlatır ve her frame'de YOLO çalıştırır.
  void _startDetection() {
    if (_isStreaming || !_controller.value.isInitialized) return;

    _isStreaming = true;
    _fpsStopwatch.start();

    _controller.startImageStream((CameraImage image) async {
      _frameCount++;
      if (_frameCount % _frameSkip != 0) return;
      if (_detector.isBusy) return;

      // Kamera sensör rotasyonunu al
      final sensorOrientation =
          widget.cameras[_selectedCameraIndex].sensorOrientation;

      final stopwatch = Stopwatch()..start();

      final results = await _detector.detect(
        image,
        imageRotation: sensorOrientation,
      );

      stopwatch.stop();
      _inferenceMs = stopwatch.elapsedMilliseconds.toDouble();

      // FPS hesapla
      _fpsFrameCount++;
      if (_fpsStopwatch.elapsedMilliseconds >= 1000) {
        _fps = _fpsFrameCount /
            (_fpsStopwatch.elapsedMilliseconds / 1000.0);
        _fpsFrameCount = 0;
        _fpsStopwatch.reset();
        _fpsStopwatch.start();
      }

      if (mounted) {
        setState(() {
          _detections = results;
        });
      }
    });
  }

  /// Kamera stream'ini durdurur.
  Future<void> _stopDetection() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    _fpsStopwatch.stop();
    try {
      await _controller.stopImageStream();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _controller.dispose();
    _detector.dispose();
    super.dispose();
  }

  void _switchCamera() {
    if (widget.cameras.length < 2) return;
    _stopDetection();
    _controller.dispose();
    setState(() {
      _selectedCameraIndex =
          _selectedCameraIndex == 0 ? widget.cameras.length - 1 : 0;
      _detections = [];
    });
    _initCamera(_selectedCameraIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Model henüz yüklenmediyse stream'i başlat
            if (_isModelLoaded && !_isStreaming) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startDetection();
              });
            }
            return _buildCameraView();
          }
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
          );
        },
      ),
    );
  }

  Widget _buildCameraView() {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        // --- Kamera Önizleme ---
        ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.previewSize?.height ?? size.width,
                height: _controller.value.previewSize?.width ?? size.height,
                child: CameraPreview(_controller),
              ),
            ),
          ),
        ),

        // --- YOLO Detection Overlay ---
        if (_detections.isNotEmpty)
          Positioned.fill(
            child: DetectionOverlay(
              detections: _detections,
              previewSize: Size(
                _controller.value.previewSize?.height ?? size.width,
                _controller.value.previewSize?.width ?? size.height,
              ),
            ),
          ),

        // --- Üst Gradient + Geri Butonu ---
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Geri butonu
                    _GlassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    // Başlık
                    const Text(
                      'YOLO Detection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    // Kamera değiştir
                    _GlassButton(
                      icon: Icons.flip_camera_ios_rounded,
                      onTap:
                          widget.cameras.length >= 2 ? _switchCamera : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // --- Model Yüklenme Durumu ---
        if (!_isModelLoaded)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1E88E5).withOpacity(0.5),
                ),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E88E5),
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'YOLO modeli yükleniyor...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // --- Alt Bilgi Paneli (FPS + Tespit Sayısı) ───────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Tespit sayısı
                _InfoChip(
                  icon: Icons.track_changes_rounded,
                  label: '${_detections.length} tespit',
                  color: const Color(0xFF4ECDC4),
                ),
                // FPS
                _InfoChip(
                  icon: Icons.speed_rounded,
                  label: '${_fps.toStringAsFixed(1)} FPS',
                  color: const Color(0xFFFFE66D),
                ),
                // Inference süresi
                _InfoChip(
                  icon: Icons.timer_rounded,
                  label: '${_inferenceMs.toStringAsFixed(0)} ms',
                  color: const Color(0xFFFF6B6B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Yardımcı Widget'lar ──────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(onTap != null ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white38,
          size: 20,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
