/// Wayfinder — Detection overlay widget.
///
/// Draws bounding boxes + labels over the camera preview.
/// Backend provides [DetectionResult] list, frontend controls visuals.
///
/// **Frontend team:** Customize colors, animations, label style.
library;

import 'package:flutter/material.dart';

import '../models/detection_result.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detections,
  });

  final List<DetectionResult> detections;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionPainter(detections),
      size: Size.infinite,
    );
  }
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter(this.detections);

  final List<DetectionResult> detections;

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final color = switch (det.dangerLevel) {
        DangerLevel.danger => Colors.red,
        DangerLevel.warning => Colors.amber,
        DangerLevel.safe => const Color(0xFF00E676),
      };

      // Scale normalized bbox to canvas size
      final rect = Rect.fromLTWH(
        det.boundingBox.left * size.width,
        det.boundingBox.top * size.height,
        det.boundingBox.width * size.width,
        det.boundingBox.height * size.height,
      );

      // Draw bounding box
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRect(rect, boxPaint);

      // Draw corner brackets for premium look
      _drawCornerBrackets(canvas, rect, color);

      // Draw label background
      final labelText =
          '${det.label} ${det.distance?.toStringAsFixed(1) ?? "?"}m';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            backgroundColor: color.withAlpha(180),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Position label above bbox
      final labelOffset = Offset(
        rect.left,
        (rect.top - textPainter.height - 4).clamp(0, size.height),
      );

      // Label background
      canvas.drawRect(
        Rect.fromLTWH(
          labelOffset.dx,
          labelOffset.dy,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        Paint()..color = color.withAlpha(180),
      );

      textPainter.paint(
        canvas,
        Offset(labelOffset.dx + 4, labelOffset.dy + 2),
      );
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const len = 15.0;

    // Top-left
    canvas.drawLine(rect.topLeft, Offset(rect.left + len, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + len), paint);

    // Top-right
    canvas.drawLine(rect.topRight, Offset(rect.right - len, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + len), paint);

    // Bottom-left
    canvas.drawLine(
        rect.bottomLeft, Offset(rect.left + len, rect.bottom), paint);
    canvas.drawLine(
        rect.bottomLeft, Offset(rect.left, rect.bottom - len), paint);

    // Bottom-right
    canvas.drawLine(
        rect.bottomRight, Offset(rect.right - len, rect.bottom), paint);
    canvas.drawLine(
        rect.bottomRight, Offset(rect.right, rect.bottom - len), paint);
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
