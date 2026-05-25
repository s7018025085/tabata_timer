import 'package:uuid/uuid.dart';
import 'package:equatable/equatable.dart';
import 'package:tabata_timer/models/voice_pack.dart';

const uuid = Uuid();

/// Модель для сохранённой программы тренировок Табата.
class TabataProgram extends Equatable {
  final String id;
  final String title;
  final int warmUpTime;
  final int workTime;
  final int restTime;
  final int roundsPerSet;
  final int breakTime;
  final int numberOfSets;
  final int coolDownTime;
  final bool isPremium;
  final String? musicPath;
  final VoicePack voicePack;
  final Map<String, String>? ttsVoice;

  TabataProgram({
    required this.title,
    required this.warmUpTime,
    required this.workTime,
    required this.restTime,
    required this.roundsPerSet,
    required this.breakTime,
    required this.numberOfSets,
    required this.coolDownTime,
    this.isPremium = false,
    this.musicPath,
    String? id,
    this.voicePack = VoicePack.standard,
    this.ttsVoice,
  }) : id = id ?? uuid.v4();

  /// Создает экземпляр [TabataProgram] из JSON.
  factory TabataProgram.fromJson(Map<String, dynamic> json) {
    return TabataProgram(
      id: json['id'] as String,
      title: json['title'] as String,
      warmUpTime: json['warmUpTime'] as int,
      workTime: json['workTime'] as int,
      restTime: json['restTime'] as int,
      roundsPerSet: json['roundsPerSet'] as int,
      breakTime: json['breakTime'] as int,
      numberOfSets: json['numberOfSets'] as int,
      coolDownTime: json['coolDownTime'] as int,
      isPremium: json['isPremium'] as bool? ?? false,
      musicPath: json['musicPath'] as String?,
      voicePack: VoicePack.values.firstWhere(
        (e) => e.toString() == json['voicePack'],
        orElse: () => VoicePack.standard,
      ),
      ttsVoice: (json['ttsVoice'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );
  }

  /// Преобразует экземпляр [TabataProgram] в JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'warmUpTime': warmUpTime,
    'workTime': workTime,
    'restTime': restTime,
    'roundsPerSet': roundsPerSet,
    'breakTime': breakTime,
    'numberOfSets': numberOfSets,
    'coolDownTime': coolDownTime,
    'isPremium': isPremium,
    'musicPath': musicPath,
    'voicePack': voicePack.toString(),
    'ttsVoice': ttsVoice,
  };

  /// Создает копию объекта с измененными полями.
  TabataProgram copyWith({
    String? id,
    String? title,
    int? warmUpTime,
    int? workTime,
    int? restTime,
    int? roundsPerSet,
    int? breakTime,
    int? numberOfSets,
    int? coolDownTime,
    bool? isPremium,
    String? musicPath,
    VoicePack? voicePack,
    Map<String, String>? ttsVoice,
  }) {
    return TabataProgram(
      id: id ?? this.id,
      title: title ?? this.title,
      warmUpTime: warmUpTime ?? this.warmUpTime,
      workTime: workTime ?? this.workTime,
      restTime: restTime ?? this.restTime,
      roundsPerSet: roundsPerSet ?? this.roundsPerSet,
      breakTime: breakTime ?? this.breakTime,
      numberOfSets: numberOfSets ?? this.numberOfSets,
      coolDownTime: coolDownTime ?? this.coolDownTime,
      isPremium: isPremium ?? this.isPremium,
      musicPath: musicPath ?? this.musicPath,
      voicePack: voicePack ?? this.voicePack,
      ttsVoice: ttsVoice ?? this.ttsVoice,
    );
  }

  /// Вычисляет общую продолжительность тренировки в секундах.
  int get totalDuration {
    // Длительность одного полного раунда (работа + отдых)
    final singleRoundDuration = workTime + restTime;

    // Длительность одного блока (сета). Последний отдых в блоке не считается.
    final singleSetDuration = (singleRoundDuration * roundsPerSet) - restTime;

    // Общая длительность всех блоков
    final allSetsDuration = singleSetDuration * numberOfSets;

    // Общая длительность перерывов между блоками.
    // Перерывов на 1 меньше, чем блоков.
    final totalBreakTime = numberOfSets > 1
        ? breakTime * (numberOfSets - 1)
        : 0;

    return warmUpTime + allSetsDuration + totalBreakTime + coolDownTime;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    warmUpTime,
    workTime,
    restTime,
    roundsPerSet,
    breakTime,
    numberOfSets,
    coolDownTime,
    isPremium,
    musicPath,
    voicePack,
    ttsVoice,
  ];

  @override
  bool get stringify => true;
}
