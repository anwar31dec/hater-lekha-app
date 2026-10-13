import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/progress_store.dart';
import '../../data/settings_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: s.language,
          child: SegmentedButton<AppLang>(
            segments: const [
              ButtonSegment(value: AppLang.bn, label: Text('বাংলা')),
              ButtonSegment(value: AppLang.en, label: Text('English')),
            ],
            selected: {settings.lang},
            onSelectionChanged: (v) => n.setLang(v.first),
          ),
        ),
        _Section(
          title: s.difficulty,
          child: SegmentedButton<Difficulty>(
            segments: [
              ButtonSegment(value: Difficulty.easy, label: Text(s.easy)),
              ButtonSegment(value: Difficulty.normal, label: Text(s.normal)),
              ButtonSegment(value: Difficulty.hard, label: Text(s.hard)),
            ],
            selected: {settings.difficulty},
            onSelectionChanged: (v) => n.setDifficulty(v.first),
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  s.soundEffects,
                  style: display(size: 16, weight: FontWeight.w600),
                ),
                secondary: const Icon(Icons.vibration_rounded),
                value: settings.sound,
                onChanged: n.setSound,
              ),
              SwitchListTile(
                title: Text(
                  s.voice,
                  style: display(size: 16, weight: FontWeight.w600),
                ),
                secondary: const Icon(Icons.record_voice_over_rounded),
                value: settings.voice,
                onChanged: n.setVoice,
              ),
              SwitchListTile(
                title: Text(
                  s.leftHanded,
                  style: display(size: 16, weight: FontWeight.w600),
                ),
                subtitle: Text(s.leftHandedHint),
                secondary: const Icon(Icons.back_hand_outlined),
                value: settings.leftHanded,
                onChanged: n.setLeftHanded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.matra,
            ),
            title: Text(
              s.resetProgress,
              style: display(
                size: 16,
                weight: FontWeight.w600,
                color: AppColors.matra,
              ),
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(s.resetProgress),
                  content: Text(s.resetConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(s.cancel),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.matra,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(s.reset),
                    ),
                  ],
                ),
              );
              if (ok == true) ref.read(progressProvider.notifier).resetAll();
            },
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: s.about,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.aboutText,
                style: display(size: 15, weight: FontWeight.w500, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                s.credits,
                style: display(
                  size: 13,
                  weight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: display(size: 17, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
