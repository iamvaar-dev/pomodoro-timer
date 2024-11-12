import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stats_storage.dart';
import '../models/session_stats.dart';

// Provider for the selected time period
final selectedPeriodProvider = StateProvider<String>((ref) => 'daily');

// Provider for all statistics data
final statsProvider = FutureProvider.family<SessionStats, String>((ref, period) async {
  return StatsStorage.loadStats(period);
});

final todayStatsProvider = FutureProvider<SessionStats>((ref) async {
  return StatsStorage.getTodayStats();
});

