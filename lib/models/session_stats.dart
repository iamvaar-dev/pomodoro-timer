class SessionStats {
  final DateTime date;
  final int focusMinutes;
  final int completedSessions;
  final List<Duration> focusSessions;

  SessionStats({
    required this.date,
    required this.focusMinutes,
    required this.completedSessions,
    List<Duration>? focusSessions,
  }) : focusSessions = focusSessions ?? [];

  // Computed properties
  Duration get totalFocusTime => Duration(minutes: focusMinutes);
  double get averageSessionLength => 
      completedSessions > 0 ? focusMinutes / completedSessions : 0;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'focusMinutes': focusMinutes,
    'completedSessions': completedSessions,
    'focusSessions': focusSessions.map((d) => d.inMinutes).toList(),
  };

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    final List<dynamic> sessions = json['focusSessions'] ?? [];
    return SessionStats(
      date: DateTime.parse(json['date']),
      focusMinutes: json['focusMinutes'],
      completedSessions: json['completedSessions'],
      focusSessions: sessions.map((m) => Duration(minutes: m as int)).toList(),
    );
  }

  SessionStats copyWith({
    DateTime? date,
    int? focusMinutes,
    int? completedSessions,
    List<Duration>? focusSessions,
  }) => SessionStats(
    date: date ?? this.date,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    completedSessions: completedSessions ?? this.completedSessions,
    focusSessions: focusSessions ?? List.from(this.focusSessions),
  );
} 