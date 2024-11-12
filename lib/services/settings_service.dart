import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _workDurationKey = 'workDuration';
  static const String _shortBreakDurationKey = 'shortBreakDuration';
  static const String _longBreakDurationKey = 'longBreakDuration';
  static const String _autoStartBreakKey = 'autoStartBreak';
  static const String _autoStartWorkKey = 'autoStartWork';
  static const String _sessionsUntilLongBreakKey = 'sessionsUntilLongBreak';

  static const defaultWorkDuration = 25 * 60;  // 25 minutes
  static const defaultShortBreakDuration = 5 * 60;  // 5 minutes
  static const defaultLongBreakDuration = 15 * 60;  // 15 minutes
  static const defaultSessionsUntilLongBreak = 4;
  static const defaultAutoStartBreak = true;
  static const defaultAutoStartWork = true;

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'workDuration': prefs.getInt(_workDurationKey) ?? defaultWorkDuration ~/ 60,
      'shortBreakDuration': prefs.getInt(_shortBreakDurationKey) ?? defaultShortBreakDuration ~/ 60,
      'longBreakDuration': prefs.getInt(_longBreakDurationKey) ?? defaultLongBreakDuration ~/ 60,
      'autoStartBreak': prefs.getBool(_autoStartBreakKey) ?? true,
      'autoStartWork': prefs.getBool(_autoStartWorkKey) ?? true,
      'sessionsUntilLongBreak': prefs.getInt(_sessionsUntilLongBreakKey) ?? defaultSessionsUntilLongBreak,
    };
  }

  static Future<void> saveSettings({
    required int workDuration,
    required int shortBreakDuration,
    required int longBreakDuration,
    required bool autoStartBreak,
    required bool autoStartWork,
    required int sessionsUntilLongBreak,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_workDurationKey, workDuration);
    await prefs.setInt(_shortBreakDurationKey, shortBreakDuration);
    await prefs.setInt(_longBreakDurationKey, longBreakDuration);
    await prefs.setBool(_autoStartBreakKey, autoStartBreak);
    await prefs.setBool(_autoStartWorkKey, autoStartWork);
    await prefs.setInt(_sessionsUntilLongBreakKey, sessionsUntilLongBreak);
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_workDurationKey, defaultWorkDuration ~/ 60);
    await prefs.setInt(_shortBreakDurationKey, defaultShortBreakDuration ~/ 60);
    await prefs.setInt(_longBreakDurationKey, defaultLongBreakDuration ~/ 60);
    await prefs.setInt(_sessionsUntilLongBreakKey, defaultSessionsUntilLongBreak);
    await prefs.setBool(_autoStartBreakKey, defaultAutoStartBreak);
    await prefs.setBool(_autoStartWorkKey, defaultAutoStartWork);
  }
} 