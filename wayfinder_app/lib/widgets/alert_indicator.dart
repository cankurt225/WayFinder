/// Wayfinder — Alert indicator widget.
///
/// Visual danger indicator bar — shows proximity status.
/// **Frontend team:** Customize positioning and animations.
library;

import 'package:flutter/material.dart';

import '../models/detection_result.dart';

class AlertIndicator extends StatelessWidget {
  const AlertIndicator({
    super.key,
    required this.dangerLevel,
    required this.closestDistance,
  });

  final DangerLevel dangerLevel;
  final double? closestDistance;

  @override
  Widget build(BuildContext context) {
    if (dangerLevel == DangerLevel.safe) return const SizedBox.shrink();

    final color = dangerLevel == DangerLevel.danger
        ? Colors.red
        : Colors.amber;

    final text = dangerLevel == DangerLevel.danger
        ? 'DİKKAT! ${closestDistance?.toStringAsFixed(1) ?? "?"}m'
        : 'Uyarı: ${closestDistance?.toStringAsFixed(1) ?? "?"}m';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: color.withAlpha(200),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
        semanticsLabel: text,
      ),
    );
  }
}
