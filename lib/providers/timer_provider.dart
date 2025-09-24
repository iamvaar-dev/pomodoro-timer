import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timer_service.dart';
import '../models/timer_state.dart';
import 'stats_provider.dart';

final timerServiceProvider = StateNotifierProvider<TimerService, TimerState>((ref) {
  return TimerService(
    onStatsUpdated: () {
      // Invalidate stats providers to trigger refresh
      ref.invalidate(todayStatsProvider);
      ref.invalidate(statsProvider);
    },
  );
});
