import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

class ParentHub extends ConsumerWidget {
  const ParentHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.parents),
          bottom: TabBar(
            tabs: [
              Tab(text: s.progress, icon: const Icon(Icons.insights_rounded)),
              Tab(text: s.settings, icon: const Icon(Icons.tune_rounded)),
            ],
          ),
        ),
        body: const TabBarView(children: [ProgressScreen(), SettingsScreen()]),
      ),
    );
  }
}
