import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabata_timer/models/tabata_program.dart';

/// Репозиторий для управления сохраненными программами Табата.
class ProgramRepository {
  static const _programsKey = 'tabata_programs';

  /// Загружает список программ из SharedPreferences.
  Future<List<TabataProgram>> getPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final programsJson = prefs.getStringList(_programsKey);

    if (programsJson == null) {
      return [];
    }

    return programsJson
        .map(
          (jsonString) => TabataProgram.fromJson(
            jsonDecode(jsonString) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Сохраняет список программ в SharedPreferences.
  Future<void> savePrograms(List<TabataProgram> programs) async {
    final prefs = await SharedPreferences.getInstance();
    final programsJson = programs
        .map((program) => jsonEncode(program.toJson()))
        .toList();
    await prefs.setStringList(_programsKey, programsJson);
  }
}
