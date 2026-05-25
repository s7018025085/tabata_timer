import 'package:flutter/material.dart';
import 'package:tabata_timer/models/voice_pack.dart';

class VoicePackSelector extends StatelessWidget {
  final VoicePack selectedPack;
  final ValueChanged<VoicePack> onPackSelected;

  const VoicePackSelector({
    super.key,
    required this.selectedPack,
    required this.onPackSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Озвучка тренировки',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildPackOption(
              context,
              VoicePack.standard,
              Icons.music_note_outlined,
              'Сигналы',
            ),
            _buildPackOption(
              context,
              VoicePack.neutral,
              Icons.record_voice_over_outlined,
              'Диктор',
            ),
            _buildPackOption(
              context,
              VoicePack.coach,
              Icons.sports_gymnastics,
              'Тренер',
            ),
            _buildPackOption(
              context,
              VoicePack.sergeant,
              Icons.military_tech,
              'Сержант',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPackOption(
    BuildContext context,
    VoicePack pack,
    IconData icon,
    String label,
  ) {
    final isSelected = selectedPack == pack;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return GestureDetector(
      onTap: () => onPackSelected(pack),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
