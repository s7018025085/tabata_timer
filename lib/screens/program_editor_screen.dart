import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tabata_timer/models/tabata_program.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tabata_timer/models/voice_pack.dart';
import 'package:tabata_timer/widgets/voice_pack_selector.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class ProgramEditorScreen extends StatefulWidget {
  final TabataProgram? program;

  const ProgramEditorScreen({super.key, this.program});

  @override
  State<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends State<ProgramEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _warmUpController;
  late final TextEditingController _workController;
  late final TextEditingController _restController;
  late final TextEditingController _roundsController;
  late final TextEditingController _breakController;
  late final TextEditingController _setsController;
  late final TextEditingController _coolDownController;

  String? _selectedMusicPath;
  late VoicePack _voicePack;
  Map<String, String>? _selectedTtsVoice;
  bool _isCopyingMusic = false;

  final FlutterTts _flutterTts = FlutterTts();
  List<Map<String, String>> _voices = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.program?.title ?? '');
    _warmUpController = TextEditingController(
      text: widget.program?.warmUpTime.toString() ?? '300',
    );
    _workController = TextEditingController(
      text: widget.program?.workTime.toString() ?? '20',
    );
    _restController = TextEditingController(
      text: widget.program?.restTime.toString() ?? '10',
    );
    _roundsController = TextEditingController(
      text: widget.program?.roundsPerSet.toString() ?? '8',
    );
    _breakController = TextEditingController(
      text: widget.program?.breakTime.toString() ?? '60',
    );
    _setsController = TextEditingController(
      text: widget.program?.numberOfSets.toString() ?? '4',
    );
    _coolDownController = TextEditingController(
      text: widget.program?.coolDownTime.toString() ?? '300',
    );
    _selectedMusicPath = widget.program?.musicPath;
    _voicePack = widget.program?.voicePack ?? VoicePack.standard;
    _selectedTtsVoice = widget.program?.ttsVoice;
    _initTts();
  }

  void _initTts() async {
    try {
      var voices = (await _flutterTts.getVoices) as List<dynamic>;
      setState(() {
        _voices = voices
            .map(
              (v) => (v as Map<dynamic, dynamic>).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            )
            .toList();

        if (_selectedTtsVoice != null &&
            !_voices.any((v) => mapEquals(v, _selectedTtsVoice!))) {
          _selectedTtsVoice = null;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _warmUpController.dispose();
    _workController.dispose();
    _restController.dispose();
    _roundsController.dispose();
    _breakController.dispose();
    _setsController.dispose();
    _coolDownController.dispose();
    super.dispose();
  }

  void _saveProgram() {
    if (_formKey.currentState!.validate()) {
      final program = _createProgramFromForm();
      Navigator.of(context).pop(program);
    }
  }

  TabataProgram _createProgramFromForm() {
    return TabataProgram(
      id: widget.program?.id,
      title: _titleController.text,
      warmUpTime: int.tryParse(_warmUpController.text) ?? 0,
      workTime: int.tryParse(_workController.text) ?? 0,
      restTime: int.tryParse(_restController.text) ?? 0,
      roundsPerSet: int.tryParse(_roundsController.text) ?? 0,
      breakTime: int.tryParse(_breakController.text) ?? 0,
      numberOfSets: int.tryParse(_setsController.text) ?? 0,
      coolDownTime: int.tryParse(_coolDownController.text) ?? 0,
      musicPath: _selectedMusicPath,
      voicePack: _voicePack,
      ttsVoice: _selectedTtsVoice,
    );
  }

  Future<void> _testSelectedVoice() async {
    if (_selectedTtsVoice != null) {
      final voiceObject = _voices.firstWhere(
        (v) => v['name'] == _selectedTtsVoice!['name'],
        orElse: () => <String, String>{},
      );
      if (voiceObject.isNotEmpty) {
        await _flutterTts.setVoice(voiceObject);
      }
      await _flutterTts.speak("Тест");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.program == null
              ? 'Новая программа'
              : 'Редактировать программу',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProgram,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildTextField(
              controller: _titleController,
              label: 'Название программы',
              validator: (value) {
                if (value == null || value.isEmpty) return 'Введите название';
                return null;
              },
            ),
            const SizedBox(height: 24),

            Text(
              'Музыка для тренировки',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedMusicPath?.split('/').last ?? 'Не выбрана',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  TextButton(
                    onPressed: _isCopyingMusic ? null : _pickMusicFile,
                    child: _isCopyingMusic
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Выбрать'),
                  ),
                  if (_selectedMusicPath != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _selectedMusicPath = null),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            VoicePackSelector(
              selectedPack: _voicePack,
              onPackSelected: (pack) => setState(() => _voicePack = pack),
            ),

            if (_voicePack != VoicePack.standard) ...[
              const SizedBox(height: 24),
              Text(
                'Голос синтезатора',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_voices.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTtsVoice?['name'],
                        items: _voices.map((voice) {
                          return DropdownMenuItem<String>(
                            value: voice['name'],
                            child: Text(
                              voice['name'] ?? 'Unknown',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newVoiceName) {
                          final newValue = _voices.firstWhere(
                            (v) => v['name'] == newVoiceName,
                            orElse: () => <String, String>{},
                          );
                          setState(() => _selectedTtsVoice = newValue);
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        isExpanded: true,
                        hint: const Text('Голос по умолчанию'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      iconSize: 32,
                      tooltip: 'Прослушать голос',
                      onPressed: _selectedTtsVoice == null
                          ? null
                          : _testSelectedVoice,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 16),
            _SliderFormField(
              label: 'Разогрев (сек)',
              controller: _warmUpController,
              activeColor: Colors.blue,
              max: 300,
              step: 1,
              onUpdated: () => setState(() {}),
            ),
            _SliderFormField(
              label: 'Работа (сек)',
              controller: _workController,
              activeColor: Colors.red,
              max: 60,
              step: 1,
              onUpdated: () => setState(() {}),
            ),
            _SliderFormField(
              label: 'Отдых (сек)',
              controller: _restController,
              activeColor: Colors.green,
              max: 60,
              step: 1,
              onUpdated: () => setState(() {}),
            ),
            _SliderFormField(
              label: 'Упражнений в сете',
              controller: _roundsController,
              activeColor: Colors.teal,
              max: 16,
              step: 1,
              onUpdated: () => setState(() {}),
            ),
            _SliderFormField(
              label: 'Перерыв (сек)',
              controller: _breakController,
              activeColor: Colors.orange,
              max: 180,
              step: 1,
              onUpdated: () => setState(() {}),
            ),
            _SliderFormField(
              label: 'Количество сетов',
              controller: _setsController,
              activeColor: Colors.cyan,
              max: 12,
              step: 1,
              onUpdated: () => setState(() {}),
            ),
            _SliderFormField(
              label: 'Заминка (сек)',
              controller: _coolDownController,
              activeColor: Colors.purple,
              max: 300,
              step: 1,
              onUpdated: () => setState(() {}),
            ),

            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text(
                    'ОБЩАЯ ДЛИТЕЛЬНОСТЬ',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    _getFormattedDuration(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveProgram,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить программу'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFormattedDuration() {
    final tempProgram = _createProgramFromForm();
    int totalSeconds = tempProgram.totalDuration;
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) return '${duration.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  Future<void> _pickMusicFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _isCopyingMusic = true);
      try {
        final file = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = p.basename(file.path);
        final persistentPath = p.join(appDir.path, 'music', fileName);

        // Создаем директорию, если она не существует
        await Directory(p.dirname(persistentPath)).create(recursive: true);

        // Копируем файл
        final copiedFile = await file.copy(persistentPath);

        setState(() {
          _selectedMusicPath = copiedFile.path;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при сохранении файла: $e')),
          );
        }
      } finally {
        setState(() => _isCopyingMusic = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}

class _SliderFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final Color activeColor;
  final double max;
  final int step;
  final VoidCallback onUpdated;

  const _SliderFormField({
    required this.controller,
    required this.label,
    required this.activeColor,
    required this.max,
    required this.step,
    required this.onUpdated,
  });

  @override
  State<_SliderFormField> createState() => _SliderFormFieldState();
}

class _SliderFormFieldState extends State<_SliderFormField> {
  late final ValueNotifier<int> _currentValueNotifier;

  @override
  void initState() {
    super.initState();
    final initial = int.tryParse(widget.controller.text) ?? 0;
    _currentValueNotifier = ValueNotifier<int>(
      initial.clamp(0, widget.max.toInt()),
    );
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _currentValueNotifier.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    final v = int.tryParse(widget.controller.text) ?? 0;
    final clamped = v.clamp(0, widget.max.toInt());
    if (clamped != _currentValueNotifier.value) {
      _currentValueNotifier.value = clamped;
    }
    widget.onUpdated();
  }

  void _updateValue(int newValue) {
    final clampedValue = newValue.clamp(0, widget.max.toInt());
    _currentValueNotifier.value = clampedValue;
    widget.controller.text = clampedValue.toString();
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    widget.onUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentValueNotifier,
                  builder: (context, value, child) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        trackShape: const RectangularSliderTrackShape(),
                      ),
                      child: Slider(
                        value: value.toDouble().clamp(0.0, widget.max),
                        activeColor: widget.activeColor,
                        min: 0,
                        max: widget.max,
                        divisions: widget.max > 0
                            ? (widget.max.toInt() ~/ widget.step)
                            : null,
                        label: value.toString(),
                        onChanged: (double newValue) =>
                            _updateValue(newValue.round()),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (s) {
                    final v = int.tryParse(s ?? '') ?? 0;
                    if (v < 0 || v > widget.max.toInt())
                      return 'Недопустимое значение';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 30,
                    width: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_drop_up),
                      onPressed: () {
                        int currentValue =
                            int.tryParse(widget.controller.text) ?? 0;
                        _updateValue(currentValue + widget.step);
                      },
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    width: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_drop_down),
                      onPressed: () {
                        int currentValue =
                            int.tryParse(widget.controller.text) ?? 0;
                        _updateValue(currentValue - widget.step);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
