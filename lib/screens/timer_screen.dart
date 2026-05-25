import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tabata_timer/models/tabata_program.dart';
import 'package:tabata_timer/models/voice_pack.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:tabata_timer/models/workout_phase.dart';
import 'package:tabata_timer/widgets/timer_painter.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TimerScreen extends StatefulWidget {
  final TabataProgram program;

  const TimerScreen({super.key, required this.program});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  late List<WorkoutPhase> _phases;
  int _currentPhaseIndex = 0;
  int _timeRemainingInPhase = 0;
  int _totalTimeRemaining = 0;
  bool _isPaused = false;
  late final ScrollController _scrollController;
  late final AnimationController _heartAnimationController;
  late final AnimationController _timerController;
  late final Animation<double> _heartAnimation;
  late final AnimationController _completionAnimationController;
  late final Animation<double> _completionAnimation;
  late final AudioPlayer _audioPlayer;
  late final AudioPlayer _soundEffectPlayer;
  late final FlutterTts _flutterTts;
  double _volume = 1.0;
  bool _isMuted = false;
  Duration? _musicDuration;
  Duration _musicPosition = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Информация о текущем раунде/сете
  int _currentRound = 0;
  int _currentSet = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Будет обновляться для каждой фазы
    );
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.elasticInOut,
      ),
    );
    _completionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _completionAnimation = CurvedAnimation(
      parent: _completionAnimationController,
      curve: Curves.elasticOut,
    );
    _audioPlayer = AudioPlayer();
    _soundEffectPlayer = AudioPlayer();
    _flutterTts = FlutterTts();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _musicDuration = duration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _musicPosition = position);
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      setState(() {});
    });

    WakelockPlus.enable();
    _phases = _generatePhases(widget.program);
    if (_phases.isNotEmpty) {
      _totalTimeRemaining = widget.program.totalDuration;
      _startPhase(_currentPhaseIndex);
    }
    _setupTts();
    _playMusic();

    _timerController.addListener(() {
      setState(() {
        final currentPhase = _phases[_currentPhaseIndex];
        final newTimeRemaining =
            ((1 - _timerController.value) * currentPhase.durationSeconds)
                .round();

        if (_timeRemainingInPhase != newTimeRemaining) {
          _timeRemainingInPhase = newTimeRemaining;
          if (!_isPaused) {
            _totalTimeRemaining = _calculateTotalRemaining();
          }

          // Логика звукового отсчета
          final isWorkPhase = currentPhase.name.startsWith('Упражнение');
          final isRestPhase =
              currentPhase.name == 'Отдых'; // Отдых между упражнениями
          final isWarmUpPhase = currentPhase.name == 'Разогрев';
          final isBreakPhase =
              currentPhase.name == 'Перерыв'; // Перерыв между сетами

          if ((isWorkPhase || isRestPhase || isWarmUpPhase || isBreakPhase) &&
              _timeRemainingInPhase <= 5 &&
              _timeRemainingInPhase > 0) {
            _playCountdownSound();
          }
        }
      });
    });

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _moveToNextPhase();
        _scrollToCurrentPhase();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Прокручиваем к начальной фазе здесь, а не в initState,
    // так как здесь уже доступен context для MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrentPhase(),
    );
  }

  void _playMusic() async {
    if (widget.program.musicPath != null) {
      final file = File(widget.program.musicPath!);
      if (await file.exists()) {
        try {
          await _audioPlayer.play(DeviceFileSource(widget.program.musicPath!));
        } catch (e) {
          debugPrint('Ошибка воспроизведения музыки: $e');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Файл музыки не найден. Пожалуйста, выберите его снова в настройках программы.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage("ru-RU");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    if (widget.program.ttsVoice != null) {
      await _flutterTts.setVoice(widget.program.ttsVoice!);
    }
  }

  List<WorkoutPhase> _generatePhases(TabataProgram program) {
    final phases = <WorkoutPhase>[];

    if (program.warmUpTime > 0) {
      phases.add(
        WorkoutPhase(
          name: 'Разогрев',
          durationSeconds: program.warmUpTime,
          colorCode: '#3498db',
          soundAsset: '',
        ),
      ); // Blue
    }

    for (int set = 1; set <= program.numberOfSets; set++) {
      for (int round = 1; round <= program.roundsPerSet; round++) {
        phases.add(
          WorkoutPhase(
            name: 'Упражнение $round',
            durationSeconds: program.workTime,
            colorCode: '#e74c3c',
            soundAsset: '',
          ),
        ); // Red
        if (round < program.roundsPerSet) {
          phases.add(
            WorkoutPhase(
              name: 'Отдых',
              durationSeconds: program.restTime,
              colorCode: '#2ecc71',
              soundAsset: '',
            ),
          ); // Green
        }
      }
      if (set < program.numberOfSets) {
        phases.add(
          WorkoutPhase(
            name: 'Перерыв',
            durationSeconds: program.breakTime,
            colorCode: '#f1c40f',
            soundAsset: '',
          ),
        ); // Yellow
      }
    }

    if (program.coolDownTime > 0) {
      phases.add(
        WorkoutPhase(
          name: 'Заминка',
          durationSeconds: program.coolDownTime,
          colorCode: '#9b59b6',
          soundAsset: '',
        ),
      ); // Purple
    }
    return phases;
  }

  void _startPhase(int phaseIndex) {
    _currentPhaseIndex = phaseIndex;
    final currentPhase = _phases[_currentPhaseIndex];
    _timeRemainingInPhase = currentPhase.durationSeconds;
    _updateRoundAndSetInfo();

    _timerController.duration = Duration(seconds: currentPhase.durationSeconds);
    _timerController.forward(from: 0);

    if (currentPhase.name.startsWith('Упражнение') ||
        currentPhase.name == 'Отдых' ||
        currentPhase.name == 'Разогрев' ||
        currentPhase.name == 'Перерыв') {
      _heartAnimationController.repeat(reverse: true);
    } else {
      _heartAnimationController.stop();
    }

    // Воспроизводим звук начала фазы
    _playPhaseStartSound(currentPhase);
  }

  void _moveToNextPhase() {
    _playPhaseEndSound();

    if (_currentPhaseIndex < _phases.length - 1) {
      _startPhase(_currentPhaseIndex + 1);
    } else {
      _endWorkout();
    }
  }

  void _endWorkout() {
    _speak(_getCompletionPhrase());

    setState(() {
      _currentPhaseIndex++; // Чтобы build() показал экран завершения
    });
    _completionAnimationController.forward(); // Запускаем анимацию завершения
    WakelockPlus.disable();
    _audioPlayer.stop();
    _heartAnimationController.stop();
    _timerController.stop();
  }

  String _getCompletionPhrase() {
    switch (widget.program.voicePack) {
      case VoicePack.coach:
      case VoicePack.neutral:
        return "Тренировка завершена!";
      case VoicePack.sergeant:
        return "Завершить тренировку!";
      case VoicePack.standard:
      default:
        // Для стандартного пакета просто покажем текст,
        // TTS не будет его произносить, так как _speak() не вызывается для standard.
        return "Финиш!";
    }
  }

  void _playPhaseStartSound(WorkoutPhase phase) {
    switch (widget.program.voicePack) {
      case VoicePack.neutral:
        _speak(phase.name);
        break;
      case VoicePack.coach:
        _speak(_getCoachPhrase(phase));
        break;
      case VoicePack.sergeant:
        _speak(_getSergeantPhrase(phase));
        break;
      case VoicePack.standard:
      default:
        _playSound('phase_start.mp3');
        break;
    }
  }

  String _getCoachPhrase(WorkoutPhase phase) {
    if (phase.name.startsWith('Упражнение')) {
      return "Работаем!";
    }
    switch (phase.name) {
      case 'Отдых':
        return "Отдых. Восстанавливаемся.";
      case 'Разогрев':
        return "Начинаем разогрев.";
      case 'Перерыв':
        return "Перерыв.";
      case 'Заминка':
        return "Заминка. Отличная работа.";
      default:
        return phase.name;
    }
  }

  String _getSergeantPhrase(WorkoutPhase phase) {
    if (phase.name.startsWith('Упражнение')) {
      return "Работать!";
    }
    switch (phase.name) {
      case 'Отдых':
        return "Передышка!";
      case 'Разогрев':
      case 'Перерыв':
      case 'Заминка':
      default:
        return phase.name;
    }
  }

  void _playPhaseEndSound() {
    // Для голосовых пакетов конец фазы означает начало следующей,
    // поэтому отдельный звук не нужен. Играем только стандартный сигнал.
    if (widget.program.voicePack == VoicePack.standard) {
      _playSound('phase_end.mp3');
    }
  }

  void _playCountdownSound() {
    if (widget.program.voicePack == VoicePack.standard) {
      _playSound('countdown_tick.mp3', volume: 1.0);
    } else {
      // Для голосовых пакетов произносим цифру
      if (_timeRemainingInPhase <= 3) {
        _speak(_timeRemainingInPhase.toString());
      }
    }
  }

  void _playSound(String fileName, {double volume = 1.0}) {
    if (!_isMuted) {
      _soundEffectPlayer.play(AssetSource('audio/$fileName'));
      _soundEffectPlayer.setVolume(volume);
    }
  }

  Future<void> _speak(String text) async {
    if (widget.program.voicePack == VoicePack.standard) return;
    await _flutterTts.speak(text);
  }

  void _scrollToCurrentPhase() {
    // Ширина контейнера (120) + горизонтальные отступы (4 + 4)
    const itemWidth = 128.0;
    final screenWidth = MediaQuery.of(context).size.width;
    // Вычисляем смещение, чтобы текущий элемент был по центру экрана
    final scrollOffset =
        (_currentPhaseIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    _scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _updateRoundAndSetInfo() {
    final phase = _phases[_currentPhaseIndex];
    // Обновляем счетчики, только когда находимся в активных фазах тренировки (Упражнение или Отдых)
    if (phase.name.startsWith('Упражнение') || phase.name == 'Отдых') {
      int workRestPairs = 0;
      for (int i = 0; i <= _currentPhaseIndex; i++) {
        if (_phases[i].name.startsWith('Упражнение')) {
          workRestPairs++;
        }
      }
      _currentSet = (workRestPairs / widget.program.roundsPerSet).ceil();
      _currentRound = workRestPairs % widget.program.roundsPerSet;
      if (_currentRound == 0) _currentRound = widget.program.roundsPerSet;
    }
  }

  int? _getNextExerciseRound() {
    for (int i = _currentPhaseIndex + 1; i < _phases.length; i++) {
      final name = _phases[i].name;
      if (name.startsWith('Упражнение')) {
        return int.tryParse(name.replaceAll('Упражнение ', ''));
      }
    }
    return null;
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _timerController.stop();
        _audioPlayer.pause();
        _heartAnimationController.stop();
      } else {
        _audioPlayer.resume();
        _timerController.forward();
        if (_phases[_currentPhaseIndex].name.startsWith('Упражнение')) {
          _heartAnimationController.repeat(reverse: true);
        }
      }
    });
  }

  void _showStopConfirmationDialog() async {
    // Приостанавливаем таймер, пока открыт диалог
    final wasPaused = _isPaused;
    if (!wasPaused) {
      _togglePause();
      _audioPlayer.pause();
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Завершить тренировку?'),
          content: const Text(
            'Вы уверены, что хотите остановить тренировку? Прогресс не будет сохранен.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Да, завершить'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      Navigator.of(context).pop();
    } else if (!wasPaused) {
      // Если пользователь нажал "Отмена", возобновляем таймер
      _togglePause();
      _audioPlayer.resume();
    }
  }

  void _promptAndJumpToPhase(int targetIndex) async {
    if (targetIndex == _currentPhaseIndex) return;

    // Приостанавливаем таймер, пока открыт диалог
    final wasPaused = _isPaused;
    if (!wasPaused) {
      _togglePause();
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Перейти к фазе?'),
          content: Text(
            'Вы уверены, что хотите перейти к фазе "${_phases[targetIndex].name}"?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Да, перейти'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _jumpToPhase(targetIndex);
      // Если таймер не был на паузе до диалога, возобновляем его
      if (!wasPaused) {
        _togglePause();
      }
    } else if (!wasPaused) {
      // Если пользователь нажал "Отмена", возобновляем таймер
      _togglePause();
    }
  }

  void _jumpToPhase(int targetIndex) {
    _timerController.stop();
    _startPhase(targetIndex);
    _totalTimeRemaining = _calculateTotalRemaining();
    setState(() {});
  }

  int _calculateTotalRemaining() {
    if (_phases.isEmpty || _currentPhaseIndex >= _phases.length) return 0;

    int remaining = _timeRemainingInPhase;
    for (int i = _currentPhaseIndex + 1; i < _phases.length; i++) {
      remaining += _phases[i].durationSeconds;
    }
    return remaining;
  }

  String _formatMusicDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showMusicControls() {
    final hasMusic = widget.program.musicPath != null;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return _MusicControlsSheet(
          audioPlayer: _audioPlayer,
          program: widget.program,
          initialPosition: _musicPosition,
          initialDuration: _musicDuration,
          initialVolume: _volume,
          isInitiallyMuted: _isMuted,
          onVolumeChanged: (volume, isMuted) {
            setState(() {
              _volume = volume;
              _isMuted = isMuted;
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _timerController.dispose();
    _scrollController.dispose();
    _heartAnimationController.dispose();
    _completionAnimationController.dispose();
    _soundEffectPlayer.dispose();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _flutterTts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).floor().toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    if (_phases.isEmpty || _currentPhaseIndex >= _phases.length) {
      final screenSize = MediaQuery.of(context).size;
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ScaleTransition(
            scale: _completionAnimation,
            child: FadeTransition(
              opacity: _completionAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/Icon/Kubok.png',
                    width: screenSize.width * 0.75,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _getCompletionPhrase(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 24),
                    ),
                    child: const Text('Отлично!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currentPhase = _phases[_currentPhaseIndex];
    final progress = 1.0 - _timerController.value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      color: currentPhase.color,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Верхняя часть: информация о сетах, общем времени и раундах (сердечки)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.layers,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_currentSet / ${widget.program.numberOfSets}',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatTime(_totalTimeRemaining),
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: List.generate(widget.program.roundsPerSet, (index) {
                        final isRoundInThePast = index + 1 < _currentRound;
                        final isCurrentRound = index + 1 == _currentRound;

                        final bool isHeartFilled = isRoundInThePast ||
                            (isCurrentRound &&
                                !_phases[_currentPhaseIndex]
                                    .name
                                    .startsWith('Упражнение'));

                        if (isCurrentRound &&
                            (_phases[_currentPhaseIndex].name.startsWith('Упражнение'))) {
                          return ScaleTransition(
                            scale: _heartAnimation,
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 20,
                            ),
                          );
                        }
                        return Icon(
                          isHeartFilled ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                          size: 20,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              // Центральная часть: название фазы и таймер
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Spacer(flex: 1),
                    if (currentPhase.name.startsWith('Упражнение'))
                      Column(
                        children: [
                          Text(
                            '$_currentRound',
                            style: const TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'УПРАЖНЕНИЕ',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Text(
                            currentPhase.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              letterSpacing: 5,
                            ),
                          ),
                          if (currentPhase.name == 'Отдых' ||
                              currentPhase.name == 'Перерыв' ||
                              currentPhase.name == 'Разогрев') ...[
                            const SizedBox(height: 8),
                            (() {
                              final nextRound = _getNextExerciseRound();
                              if (nextRound != null) {
                                return Column(
                                  children: [
                                    ScaleTransition(
                                      scale: _heartAnimation,
                                      child: Text(
                                        '$nextRound',
                                        style: const TextStyle(
                                          fontSize: 50,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      'СЛЕДУЮЩЕЕ УПРАЖНЕНИЕ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            }()),
                          ],
                        ],
                      ),
                    const Spacer(flex: 1),
                    Flexible(
                      flex: 10, // Увеличиваем приоритет таймера
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: TimerPainter(
                                    progress: progress,
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                Center(
                                  child: FittedBox(
                                    child: Text(
                                      '$_timeRemainingInPhase',
                                      style: const TextStyle(
                                        fontSize: 200, // Увеличили базовый размер, FittedBox масштабирует
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
              // Нижняя часть: список фаз
              SizedBox(
                height: 50,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _phases.length,
                  itemBuilder: (context, index) {
                    final phase = _phases[index];
                    final isCurrent = index == _currentPhaseIndex;
                    final isPast = index < _currentPhaseIndex;

                    return GestureDetector(
                      onTap: () => _promptAndJumpToPhase(index),
                      child: Container(
                        width:
                            120, // Немного увеличим ширину для длинных названий
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            phase.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isCurrent
                                  ? currentPhase.color
                                  : Colors.white.withOpacity(
                                      isPast ? 0.3 : 0.8,
                                    ),
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Общий прогресс-бар тренировки
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: LinearProgressIndicator(
                  value:
                      1 - (_totalTimeRemaining / widget.program.totalDuration),
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Нижняя часть: кнопки управления
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        size: 36,
                        color: Colors.white,
                      ),
                      onPressed: _togglePause,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.music_note,
                        size: 36,
                        color: Colors.white,
                      ),
                      onPressed: _showMusicControls,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.stop,
                        size: 36,
                        color: Colors.white,
                      ),
                      onPressed: _showStopConfirmationDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Отдельный виджет для управления плеером, чтобы инкапсулировать его состояние.
class _MusicControlsSheet extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final TabataProgram program;
  final Duration initialPosition;
  final Duration? initialDuration;
  final double initialVolume;
  final bool isInitiallyMuted;
  final Function(double volume, bool isMuted) onVolumeChanged;

  const _MusicControlsSheet({
    required this.audioPlayer,
    required this.program,
    required this.initialPosition,
    this.initialDuration,
    required this.initialVolume,
    required this.isInitiallyMuted,
    required this.onVolumeChanged,
  });

  @override
  State<_MusicControlsSheet> createState() => _MusicControlsSheetState();
}

class _MusicControlsSheetState extends State<_MusicControlsSheet> {
  late Duration _musicPosition;
  late Duration? _musicDuration;
  late PlayerState _playerState;
  late double _volume;
  late bool _isMuted;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _musicPosition = widget.initialPosition;
    _musicDuration = widget.initialDuration;
    _playerState = widget.audioPlayer.state;
    _volume = widget.initialVolume;
    _isMuted = widget.isInitiallyMuted;

    // Подписываемся на все потоки плеера
    _durationSub = widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _musicDuration = duration);
    });
    _positionSub = widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _musicPosition = position);
    });
    _stateSub = widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
  }

  @override
  void dispose() {
    // Отменяем все подписки при закрытии окна
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  String _formatMusicDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final hasMusic = widget.program.musicPath != null;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Громкость музыки",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.program.musicPath?.split('/').last ?? 'Без музыки',
            style: const TextStyle(color: Colors.white70),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Slider(
            min: 0,
            max: hasMusic && (_musicDuration?.inSeconds.toDouble() ?? 0.0) > 0
                ? _musicDuration!.inSeconds.toDouble()
                : 1.0,
            value:
                hasMusic &&
                    (_musicDuration != null && _musicDuration! > Duration.zero)
                ? _musicPosition.inSeconds.toDouble().clamp(
                    0.0,
                    _musicDuration!.inSeconds.toDouble(),
                  )
                : 0.0,
            onChanged: hasMusic
                ? (value) async {
                    final position = Duration(seconds: value.toInt());
                    // Обновляем UI немедленно для отзывчивости
                    setState(() => _musicPosition = position);
                    await widget.audioPlayer.seek(position);
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMusicDuration(_musicPosition),
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  _formatMusicDuration(_musicDuration),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: hasMusic
                    ? () async {
                        final newPosition =
                            _musicPosition - const Duration(seconds: 10);
                        await widget.audioPlayer.seek(
                          newPosition > Duration.zero
                              ? newPosition
                              : Duration.zero,
                        );
                      }
                    : null,
              ),
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _playerState == PlayerState.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: hasMusic
                    ? () {
                        if (_playerState == PlayerState.playing) {
                          widget.audioPlayer.pause();
                        } else {
                          widget.audioPlayer.resume();
                        }
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: hasMusic
                    ? () async {
                        final newPosition =
                            _musicPosition + const Duration(seconds: 10);
                        if (_musicDuration != null &&
                            newPosition < _musicDuration!) {
                          await widget.audioPlayer.seek(newPosition);
                        }
                      }
                    : null,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    final newVolume = _isMuted ? 0.0 : _volume;
                    widget.audioPlayer.setVolume(newVolume);
                    widget.onVolumeChanged(newVolume, _isMuted);
                  });
                },
              ),
              Expanded(
                child: Slider(
                  value: _isMuted ? 0 : _volume,
                  onChanged: (newVolume) {
                    setState(() {
                      _isMuted = newVolume == 0;
                      _volume = newVolume;
                      widget.audioPlayer.setVolume(_volume);
                      widget.onVolumeChanged(_volume, _isMuted);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
