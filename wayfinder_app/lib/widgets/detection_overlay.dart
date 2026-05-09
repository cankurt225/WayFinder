import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/yolo_detector.dart';

/// Kamera görüntüsünün üzerine bounding box ve etiketleri çizen widget.
class DetectionOverlay extends StatelessWidget {
  final List<DetectionResult> detections;
  final Size previewSize;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.previewSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionPainter(
        detections: detections,
        previewSize: previewSize,
      ),
      size: Size.infinite,
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size previewSize;

  // Sınıf renklerinin önceden tanımlanmış paleti
  static const List<Color> _colorPalette = [
    Color(0xFFFF6B6B), // Kırmızı
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFE66D), // Sarı
    Color(0xFF95E1D3), // Mint
    Color(0xFFF38181), // Mercan
    Color(0xFFAA96DA), // Lavanta
    Color(0xFFFC5185), // Pembe
    Color(0xFF3DC1D3), // Cyan
    Color(0xFFF6D186), // Altın
    Color(0xFF78E08F), // Yeşil
    Color(0xFFF8A5C2), // Gül
    Color(0xFF63CDDA), // Açık Mavi
    Color(0xFFE77F67), // Turuncu
    Color(0xFFCF6A87), // Bordo
    Color(0xFF786FA6), // Mor
    Color(0xFFF19066), // Şeftali
    Color(0xFF546DE5), // İndigo
    Color(0xFFE15F41), // Kırmızı-Turuncu
    Color(0xFF574B90), // Koyu Mor
    Color(0xFF3B3B98), // Koyu Mavi
  ];

  _DetectionPainter({
    required this.detections,
    required this.previewSize,
  });

  Color _getColorForClass(int classIndex) {
    return _colorPalette[classIndex % _colorPalette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      final color = _getColorForClass(detection.classIndex);

      // Normalize koordinatları ekran piksellerine dönüştür
      final double left = detection.x * size.width;
      final double top = detection.y * size.height;
      final double right = (detection.x + detection.width) * size.width;
      final double bottom = (detection.y + detection.height) * size.height;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // ── Bounding Box ───────────────────────────────────────
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      // Köşeleri yuvarlatılmış box
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, boxPaint);

      // Yarı saydam dolgu
      final fillPaint = Paint()
        ..color = color.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, fillPaint);

      // ── Label Arka Plan + Metin ────────────────────────────
      final labelText =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';

      final textStyle = ui.TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          maxLines: 1,
        ),
      )
        ..pushStyle(textStyle)
        ..addText(labelText);

      final paragraph = paragraphBuilder.build()
        ..layout(const ui.ParagraphConstraints(width: 300));

      final textWidth = paragraph.longestLine;
      final textHeight = paragraph.height;

      // Label arka plan kutusu
      final labelPadH = 6.0;
      final labelPadV = 3.0;
      final labelBgRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          left,
          top - textHeight - labelPadV * 2,
          textWidth + labelPadH * 2,
          textHeight + labelPadV * 2,
        ),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );

      // Label arkaplanının ekranın üstüne taşmasını önle
      final adjustedLabelBg = labelBgRect.shift(
        Offset(0, top - textHeight - labelPadV * 2 < 0 ? textHeight + labelPadV * 2 + rect.height : 0),
      );

      final labelBgPaint = Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(adjustedLabelBg, labelBgPaint);

      // Label metni
      final textOffset = Offset(
        adjustedLabelBg.left + labelPadH,
        adjustedLabelBg.top + labelPadV,
      );
      canvas.drawParagraph(paragraph, textOffset);
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
