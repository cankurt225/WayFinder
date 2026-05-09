import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../services/detection_service.dart';
import '../models/detection_result.dart';
import '../utils/constants.dart';
import '../widgets/detection_overlay.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  
  final YOLOViewController _yoloController = YOLOViewController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final detectionService = context.read<DetectionService>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        detectionService.pause();
        break;
      case AppLifecycleState.resumed:
        detectionService.resume();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detectionService = context.read<DetectionService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- YOLO Camera View (Backend core) ---
          LayoutBuilder(
            builder: (context, constraints) {
              // Capture camera preview height for distance estimation math
              detectionService.imageHeight = constraints.maxHeight.toInt();
              return YOLOView(
                modelPath: kDefaultModelId, // 'yolo26n'
                task: YOLOTask.detect,
                controller: _yoloController,
                onResult: (results) {
                  // Pipe results to backend service
                  detectionService.onYoloResults(results);
                },
              );
            },
          ),

          // --- YOLO Detection Overlay ---
          Consumer<DetectionService>(
            builder: (context, service, _) {
              if (service.currentDetections.isEmpty) return const SizedBox.shrink();
              return DetectionOverlay(
                detections: service.currentDetections,
              );
            },
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
                        'WayFinder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Kamera değiştir (YOLOView'da şu an desteklenmediği için boş bırakıyoruz)
                      _GlassButton(
                        icon: Icons.flip_camera_ios_rounded,
                        onTap: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- Alt Bilgi Paneli (FPS + Tespit Sayısı) ───────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<DetectionService>(
              builder: (context, service, _) {
                return Container(
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
                        label: '${service.currentDetections.length} tespit',
                        color: const Color(0xFF4ECDC4),
                      ),
                      // FPS
                      _InfoChip(
                        icon: Icons.speed_rounded,
                        label: '${service.effectiveFps.toStringAsFixed(1)} FPS',
                        color: const Color(0xFFFFE66D),
                      ),
                      // Durum
                      _InfoChip(
                        icon: service.state == PipelineState.running 
                            ? Icons.play_arrow_rounded 
                            : Icons.pause_rounded,
                        label: service.state.name.toUpperCase(),
                        color: service.state == PipelineState.running 
                            ? const Color(0xFF00E676) 
                            : Colors.amber,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
