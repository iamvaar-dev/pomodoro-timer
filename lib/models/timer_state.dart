class TimerState {
  final int completedSessions;
  final Duration totalFocusTime;
  final bool isRunning;
  final Duration currentDuration;
  final bool isBreak;
  final bool isLongBreak;
  final Duration totalDuration;

  TimerState({
    required this.completedSessions,
    required this.totalFocusTime,
    required this.isRunning,
    required this.currentDuration,
    required this.isBreak,
    required this.isLongBreak,
    required this.totalDuration,
  });

  int get minutes => currentDuration.inMinutes;
  int get seconds => currentDuration.inSeconds % 60;
  bool get isBreakTime => isBreak;
  double get progress {
    if (totalDuration.inSeconds == 0) return 0.0;
    final elapsedSeconds = totalDuration.inSeconds - currentDuration.inSeconds;
    return elapsedSeconds / totalDuration.inSeconds;
  }

  TimerState copyWith({
    int? completedSessions,
    Duration? totalFocusTime,
    bool? isRunning,
    Duration? currentDuration,
    bool? isBreak,
    bool? isLongBreak,
    Duration? totalDuration,
  }) {
    return TimerState(
      completedSessions: completedSessions ?? this.completedSessions,
      totalFocusTime: totalFocusTime ?? this.totalFocusTime,
      isRunning: isRunning ?? this.isRunning,
      currentDuration: currentDuration ?? this.currentDuration,
      isBreak: isBreak ?? this.isBreak,
      isLongBreak: isLongBreak ?? this.isLongBreak,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}