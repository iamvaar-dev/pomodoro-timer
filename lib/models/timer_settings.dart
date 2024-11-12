class TimerSettings {
  final int workDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final bool autoStartBreak;
  final bool autoStartWork;
  final int sessionsUntilLongBreak;

  const TimerSettings({
    this.workDuration = 25 * 60,  // 25 minutes in seconds
    this.shortBreakDuration = 5 * 60,  // 5 minutes in seconds
    this.longBreakDuration = 15 * 60,  // 15 minutes in seconds
    this.autoStartBreak = true,
    this.autoStartWork = true,
    this.sessionsUntilLongBreak = 4,  // Long break after 4 sessions
  });
} 