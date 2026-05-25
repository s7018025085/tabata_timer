import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/tabata_program.dart';
import 'screens/program_editor_screen.dart';
import 'program_repository.dart';
import 'screens/timer_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

void main() async {
  // Убедимся, что все биндинги Flutter инициализированы перед вызовом
  // кода, специфичного для платформы.
  WidgetsFlutterBinding.ensureInitialized();

  // Устанавливаем предпочтительные ориентации экрана (только книжная).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tabata Timer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ProgramsScreen(),
    );
  }
}

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  final ProgramRepository _repository = ProgramRepository();
  List<TabataProgram> _programs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    var programs = await _repository.getPrograms();

    // Если программы не найдены (первый запуск), создаем и сохраняем стандартные
    if (programs.isEmpty) {
      programs = [
        TabataProgram(
          title: 'Утренняя Табата 4 мин.',
          warmUpTime: 0,
          workTime: 20,
          restTime: 10,
          roundsPerSet: 8,
          breakTime: 0,
          numberOfSets: 1,
          coolDownTime: 0,
        ),
        TabataProgram(
          title: 'Вечерний HIIT (30/15)',
          warmUpTime: 60,
          workTime: 30,
          restTime: 15,
          roundsPerSet: 5,
          breakTime: 60,
          numberOfSets: 3,
          coolDownTime: 60,
        ),
        TabataProgram(
          title: 'Продвинутый Мета-Сет',
          warmUpTime: 120,
          workTime: 40,
          restTime: 20,
          roundsPerSet: 6,
          breakTime: 90,
          numberOfSets: 2,
          coolDownTime: 120,
          isPremium: true,
        ),
      ];
      await _repository.savePrograms(programs);
    }

    setState(() {
      _programs = programs;
      _isLoading = false;
    });
  }

  Future<void> _savePrograms() async {
    await _repository.savePrograms(_programs);
  }

  void _navigateAndAddProgram() async {
    final newProgram = await Navigator.of(context).push<TabataProgram>(
      MaterialPageRoute(
        builder: (context) => const ProgramEditorScreen(program: null),
      ),
    );

    if (newProgram != null) {
      setState(() {
        _programs.add(newProgram);
      });
      await _savePrograms();
    }
  }

  void _navigateAndEditProgram(TabataProgram program, int index) async {
    final updatedProgram = await Navigator.of(context).push<TabataProgram>(
      MaterialPageRoute(
        // Передаем существующую программу для редактирования
        builder: (context) => ProgramEditorScreen(program: program),
      ),
    );

    if (updatedProgram != null) {
      setState(() {
        _programs[index] = updatedProgram;
      });
      await _savePrograms();
    }
  }

  void _deleteProgram(int index) {
    final removedProgram = _programs.removeAt(index);
    _savePrograms(); // Сохраняем изменения

    // Показываем SnackBar с возможностью отмены
    ScaffoldMessenger.of(context).clearSnackBars(); // Убираем старые
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Программа "${removedProgram.title}" удалена.'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'ОТМЕНА',
          onPressed: () {
            setState(() => _programs.insert(index, removedProgram));
            _savePrograms();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Мои Программы',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: _programs.isEmpty
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(20),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Смахните тренировку для удаления',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProgramsList(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateAndAddProgram,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Добавить новую программу'),
        // Можно настроить стиль под ваш дизайн
        // style: FloatingActionButton.styleFrom(
        //   backgroundColor: Colors.blue,
        // ),
      ),
    );
  }

  Widget _buildProgramsList() {
    if (_programs.isEmpty) {
      return const Center(
        child: Text('Нажмите "+", чтобы добавить первую программу.'),
      );
    }

    return AnimationLimiter(
      child: ListView.separated(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 88, // Уменьшаем отступ, т.к. FAB занимает место
        ),
        itemCount: _programs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildProgramCard(context, index, _programs[index]),
      ),
    );
  }

  Widget _buildProgramCard(
    BuildContext context,
    int index,
    TabataProgram program,
  ) {
    final isPremium = program.isPremium;
    final textColor = isPremium ? Colors.white.withOpacity(0.6) : Colors.white;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Dismissible(
            key: Key(program.id),
            onDismissed: (direction) {
              _deleteProgram(index);
            },
            background: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20.0),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: GestureDetector(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            program.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isPremium) ...[
                          _buildEditButton(program, index),
                          const SizedBox(width: 8),
                        ],
                        if (isPremium)
                          _buildPremiumLock()
                        else
                          _buildPlayButton(program),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFF424242)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildParameterInfo(
                          'Длительность',
                          _formatDuration(program.totalDuration),
                          textColor,
                          textColor,
                        ),
                        _buildParameterInfo(
                          'Работа',
                          '${program.workTime}с',
                          textColor,
                          Colors.red,
                        ),
                        _buildParameterInfo(
                          'Отдых',
                          '${program.restTime}с',
                          textColor,
                          Colors.green,
                        ),
                        _buildParameterInfo(
                          'Упражнения',
                          '${program.roundsPerSet * program.numberOfSets}',
                          textColor,
                          Colors.teal,
                        ),
                        _buildParameterInfo(
                          'Сеты',
                          '${program.numberOfSets}',
                          textColor,
                          Colors.cyan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLock() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock, color: Colors.orange, size: 24),
    );
  }

  Widget _buildEditButton(TabataProgram program, int index) {
    return GestureDetector(
      onTap: () => _navigateAndEditProgram(program, index),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.edit_outlined, color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _buildPlayButton(TabataProgram program) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => TimerScreen(program: program)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildParameterInfo(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: labelColor.withOpacity(0.7)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
