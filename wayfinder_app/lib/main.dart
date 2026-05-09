import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'screens/camera_screen.dart';
import 'services/detection_service.dart';
import 'services/distance_estimator.dart';
import 'services/voice_guide.dart';
import 'services/spatial_audio.dart';
import 'utils/device_profiler.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 1. Profile device capabilities
  await DeviceProfiler.initialize();

  // 2. Create backend services
  final distanceEstimator = DistanceEstimator();
  final detectionService = DetectionService(
    distanceEstimator: distanceEstimator,
  );
  final voiceGuide = VoiceGuide();
  final spatialAudio = SpatialAudio();

  // 3. Initialize async services
  await Future.wait([
    detectionService.initialize(),
    voiceGuide.initialize(),
    spatialAudio.initialize(),
  ]);

  // 4. Wire up audio consumers to detection stream
  voiceGuide.listenTo(detectionService.detections);
  spatialAudio.listenTo(detectionService.detections);

  // 5. Welcome message
  await voiceGuide.speakImmediate('WayFinder başlatıldı. Kamerayı açın.');

  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('Kameralar alınamadı: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DetectionService>(
          create: (_) => detectionService,
        ),
        Provider<VoiceGuide>(
          create: (_) => voiceGuide,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<SpatialAudio>(
          create: (_) => spatialAudio,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<DistanceEstimator>.value(value: distanceEstimator),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WayFinder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: MyHomePage(cameras: _cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyHomePage({super.key, required this.cameras});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> _openCamera() async {
    // Kamera izni iste
    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isGranted) {
      if (widget.cameras.isEmpty) {
        _showError('Bu cihazda kamera bulunamadı.');
        return;
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CameraScreen(cameras: widget.cameras),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    } else {
      _showError('Kamera izni verilmedi.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Kamera İzni', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Kamera özelliğini kullanabilmek için lütfen uygulama ayarlarından kamera iznini verin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Ayarlara Git'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar alanı ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF1E88E5).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: Color(0xFF1E88E5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'WayFinder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Ana içerik ─────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // İkon / hero alanı
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF1E88E5).withOpacity(0.25),
                              const Color(0xFF1E88E5).withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF1E88E5).withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF1E88E5),
                          size: 60,
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'Çevrenizi Keşfedin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Kamerayı açarak görsel navigasyon\ndeneyimini başlatın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ── Kamera Butonu ────────────────────────────────
                      GestureDetector(
                        onTap: _openCamera,
                        child: Container(
                          width: 220,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E88E5),
                                Color(0xFF1565C0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5)
                                    .withOpacity(0.45),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Kamerayı Aç',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Alt bilgi ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'WayFinder v1.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
