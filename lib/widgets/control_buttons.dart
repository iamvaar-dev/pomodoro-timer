import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import 't_button.dart';

class ControlButtons extends ConsumerWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerServiceProvider);
    final timerService = ref.read(timerServiceProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TButton(
          width: 120,
          isOutlined: true,
          onPressed: timerService.resetTimer,
          child: const Text('Reset'),
        ),
        const SizedBox(width: 16),
        TButton(
          width: 120,
          onPressed: timerState.isRunning
              ? timerService.pauseTimer
              : timerService.startTimer,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                timerState.isRunning ? Icons.pause : Icons.play_arrow,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(timerState.isRunning ? 'Pause' : 'Start'),
            ],
          ),
        ),
      ],
    );
  }
} 