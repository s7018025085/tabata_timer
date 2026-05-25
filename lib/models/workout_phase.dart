import 'package:flutter/material.dart';

/// Базовая модель для одной фазы тренировки (работа, отдых и т.д.).
class WorkoutPhase {
  final String name;
  final int durationSeconds;
  final String colorCode;
  final String soundAsset;

  WorkoutPhase({
    required this.name,
    required this.durationSeconds,
    required this.colorCode,
    required this.soundAsset,
  });

  /// Вспомогательный геттер для преобразования HEX-строки в объект [Color].
  Color get color {
    final hexCode = colorCode.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
