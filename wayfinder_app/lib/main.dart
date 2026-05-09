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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0C), // Softer deep dark
        primaryColor: const Color(0xFFD4FF00), // Neon yellow/green
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4FF00),
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
        backgroundColor: const Color(0xFF16161A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF2A2A35), width: 1)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Color(0xFFD4FF00)),
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
              backgroundColor: const Color(0xFFD4FF00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Ayarlara Git', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color neonYellow = const Color(0xFFD4FF00);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A20),
              Color(0xFF0A0A0C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar alanı ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.explore_rounded,
                        color: neonYellow,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'WAYFINDER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        shadows: [
                          Shadow(color: neonYellow.withOpacity(0.3), blurRadius: 15),
                        ],
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
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E1E24),
                          border: Border.all(
                            color: neonYellow,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: neonYellow.withOpacity(0.15),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: neonYellow,
                          size: 70,
                        ),
                      ),

                      const SizedBox(height: 40),

                      const Text(
                        'Çevrenizi Keşfedin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Kamerayı açarak gelişmiş görsel navigasyon\ndeneyimini başlatın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 56),

                      // ── Kamera Butonu ────────────────────────────────
                      GestureDetector(
                        onTap: _openCamera,
                        child: Container(
                          width: 260,
                          height: 64,
                          decoration: BoxDecoration(
                            color: neonYellow,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: neonYellow.withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.power_settings_new_rounded,
                                  color: Colors.black, size: 28),
                              SizedBox(width: 12),
                              Text(
                                'KAMERAYI AÇ',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
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
