import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';

/// A small arithmetic question that keeps curious little fingers out of the
/// grown-up area without needing a password.
Future<bool> showParentGate(BuildContext context, Strings s) async {
  final rnd = Random();
  final a = 3 + rnd.nextInt(7);
  final b = 2 + rnd.nextInt(8);
  final answer = a * b;
  final options = <int>{answer};
  while (options.length < 4) {
    options.add(answer + rnd.nextInt(13) - 6);
  }
  final shuffled = options.where((o) => o > 0).toList()..shuffle(rnd);
  if (!shuffled.contains(answer)) shuffled[0] = answer;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      var wrong = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(s.parentGateTitle, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.parentGateQuestion,
                style: display(size: 16, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                '${s.num(a)} × ${s.num(b)} = ?',
                style: display(size: 30, weight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final o in shuffled)
                    FilledButton.tonal(
                      onPressed: () {
                        if (o == answer) {
                          Navigator.of(context).pop(true);
                        } else {
                          setState(() => wrong = true);
                        }
                      },
                      child: Text(s.num(o)),
                    ),
                ],
              ),
              if (wrong) ...[
                const SizedBox(height: 12),
                Text(
                  s.wrongAnswer,
                  style: display(
                    size: 15,
                    weight: FontWeight.w600,
                    color: AppColors.matra,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
