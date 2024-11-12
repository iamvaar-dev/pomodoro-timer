import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timer_service.dart';

final timerServiceProvider = StateNotifierProvider<TimerService, TimerState>((ref) {
  return TimerService();
});
