import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../widgets/timer_display.dart';
import '../widgets/control_buttons.dart';
import '../widgets/stats_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import '../widgets/task_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerServiceProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: WindowTitleBarBox(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: MoveWindow(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'FocusForge',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildHeaderButton(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  () => Navigator.pushNamed(context, '/settings'),
                ),
                _buildHeaderButton(
                  context,
                  Icons.bar_chart,
                  'Statistics',
                  () => Navigator.pushNamed(context, '/stats'),
                ),
                const SizedBox(width: 8),
                const WindowButtons(),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TimerDisplay(),
              const SizedBox(height: 24),
              const ControlButtons(),
              const SizedBox(height: 24),
              StatsCard(
                completedSessions: timerState.completedSessions,
                totalFocusTime: timerState.totalFocusTime.inMinutes,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 300,
                child: const TaskList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      mouseOver: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      mouseDown: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      iconMouseOver: Theme.of(context).colorScheme.primary,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      mouseOver: Colors.red.withOpacity(0.1),
      mouseDown: Colors.red.withOpacity(0.2),
      iconMouseOver: Colors.red,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
} 