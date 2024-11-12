import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/stats_display.dart';
import '../widgets/window_buttons.dart';
import '../providers/timer_provider.dart';
import '../services/stats_storage.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

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
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                ),
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
                const WindowButtons(),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatsDisplay(),
            const SizedBox(height: 24),
            _buildStatsHistory(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHistory(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const StatsHistoryList(),
        ],
      ),
    );
  }
}

class StatsHistoryList extends StatelessWidget {
  const StatsHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHistoryItem(
          context,
          date: 'Today',
          sessions: 4,
          duration: '2h 30m',
        ),
        const Divider(height: 32),
        _buildHistoryItem(
          context,
          date: 'Yesterday',
          sessions: 6,
          duration: '3h 45m',
        ),
        // Add more history items as needed
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context, {
    required String date,
    required int sessions,
    required String duration,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            date,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Expanded(
          child: Text(
            '$sessions sessions',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          duration,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
} 