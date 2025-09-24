import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/stats_storage.dart';
import '../services/notification_service.dart';
import '../models/session_stats.dart';
import '../models/timer_state.dart';
import '../services/settings_service.dart';
import '../services/desktop_overlay_service.dart';

class TimerService extends StateNotifier<TimerState> {
  Timer? _timer;
  late int _workDuration;
  late int _shortBreakDuration;
  late int _longBreakDuration;
  late bool _autoStartBreak;
  late bool _autoStartWork;
  late bool _isBreakTime;
  late bool _isLongBreak;
  late int _sessionsUntilLongBreak;
  late SharedPreferences _prefs;
  final VoidCallback? onStatsUpdated;

  int get workDuration => _workDuration;
  int get shortBreakDuration => _shortBreakDuration;
  int get longBreakDuration => _longBreakDuration;
  bool get autoStartBreak => _autoStartBreak;
  bool get autoStartWork => _autoStartWork;
  bool get isBreakTime => _isBreakTime;
  bool get isLongBreak => _isLongBreak;
  int get sessionsUntilLongBreak => _sessionsUntilLongBreak;

  TimerService({this.onStatsUpdated}) : super(TimerState(
    completedSessions: 0,
    totalFocusTime: const Duration(),
    isRunning: false,
    currentDuration: const Duration(minutes: 25),
    isBreak: false,
    isLongBreak: false,
    totalDuration: const Duration(minutes: 25),
  )) {
    _workDuration = 25 * 60;
    _shortBreakDuration = 5 * 60;
    _longBreakDuration = 15 * 60;
    _autoStartBreak = true;
    _autoStartWork = false;
    _isBreakTime = false;
    _isLongBreak = false;
    _sessionsUntilLongBreak = 4;
    
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _initPrefs();
    await _initSettings();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Get today's date key
      final today = DateTime.now().toIso8601String().split('T')[0];
      final lastSessionDate = _prefs.getString('lastSessionDate') ?? today;
      
      // Reset stats if it's a new day
      if (lastSessionDate != today) {
        await _prefs.setInt('completedSessions', 0);
        await _prefs.setInt('totalFocusTime', 0);
        await _prefs.setString('lastSessionDate', today);
      }
      
      final completedSessions = _prefs.getInt('completedSessions') ?? 0;
      final totalFocusTime = Duration(
        seconds: _prefs.getInt('totalFocusTime') ?? 0
      );
      
      state = state.copyWith(
        completedSessions: completedSessions,
        totalFocusTime: totalFocusTime,
      );
    } catch (e) {
      print('Error initializing preferences: $e');
    }
  }

  Future<void> _initSettings() async {
    try {
      final settings = await SettingsService.loadSettings();
      _workDuration = settings['workDuration'] * 60;
      _shortBreakDuration = settings['shortBreakDuration'] * 60;
      _longBreakDuration = settings['longBreakDuration'] * 60;
      _autoStartBreak = settings['autoStartBreak'];
      _autoStartWork = settings['autoStartWork'];
      _sessionsUntilLongBreak = settings['sessionsUntilLongBreak'];
      
      if (!state.isRunning) {
        final newDuration = Duration(
          seconds: _isBreakTime ? _shortBreakDuration : _workDuration
        );
        state = state.copyWith(
          currentDuration: newDuration,
          totalDuration: newDuration,
        );
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> savePreferences() async {
    try {
      await _prefs.setInt('completedSessions', state.completedSessions);
      await _prefs.setInt('totalFocusTime', state.totalFocusTime.inSeconds);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  void _tick() {
    if (state.currentDuration.inSeconds > 0) {
      state = state.copyWith(
        currentDuration: Duration(seconds: state.currentDuration.inSeconds - 1),
      );
      
      // Update desktop overlay with current timer status
      if (Platform.isWindows || Platform.isMacOS) {
        final minutes = state.currentDuration.inMinutes;
        final seconds = state.currentDuration.inSeconds % 60;
        final timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        final sessionType = state.isBreak ? (state.isLongBreak ? 'Long Break' : 'Break') : 'Focus';
        
        DesktopOverlayService.updateSystemTray('$sessionType $timerText', state.isRunning);
      }
    } else {
      _timer?.cancel();
      _completeSession();
    }
  }

  void startTimer() {
    if (!state.isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      state = state.copyWith(isRunning: true);
      
      // Update desktop overlay when timer starts
      if (Platform.isWindows || Platform.isMacOS) {
        final minutes = state.currentDuration.inMinutes;
        final seconds = state.currentDuration.inSeconds % 60;
        final timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        final sessionType = state.isBreak ? (state.isLongBreak ? 'Long Break' : 'Break') : 'Focus';
        
        DesktopOverlayService.updateSystemTray('$sessionType $timerText', true);
      }
    }
  }

  void pauseTimer() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
    
    // Update desktop overlay when timer pauses
    if (Platform.isWindows || Platform.isMacOS) {
      final minutes = state.currentDuration.inMinutes;
      final seconds = state.currentDuration.inSeconds % 60;
      final timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      final sessionType = state.isBreak ? (state.isLongBreak ? 'Long Break' : 'Break') : 'Focus';
      
      DesktopOverlayService.updateSystemTray('$sessionType $timerText', false);
    }
  }

  Future<void> _completeSession() async {
    try {
      final sessionDuration = Duration(
        seconds: _isBreakTime 
            ? (_isLongBreak ? _longBreakDuration : _shortBreakDuration)
            : _workDuration
      );
      
      if (!_isBreakTime) {
        await StatsStorage.saveSession(sessionDuration);
        final todayStats = await StatsStorage.getTodayStats();
        
        final needsLongBreak = todayStats.completedSessions % _sessionsUntilLongBreak == 0;
        
        state = state.copyWith(
          completedSessions: todayStats.completedSessions,
          totalFocusTime: Duration(minutes: todayStats.focusMinutes),
        );
        
        _isLongBreak = needsLongBreak;
        
        await savePreferences();
        
        // Notify that stats have been updated
        onStatsUpdated?.call();
      }
      
      _isBreakTime = !_isBreakTime;
      if (!_isBreakTime) _isLongBreak = false;
      
      // Set new duration with totalDuration
      final newDuration = Duration(
        seconds: _isBreakTime 
            ? (_isLongBreak ? _longBreakDuration : _shortBreakDuration)
            : _workDuration
      );
      
      state = state.copyWith(
        isRunning: false,
        isBreak: _isBreakTime,
        isLongBreak: _isLongBreak,
        currentDuration: newDuration,
        totalDuration: newDuration,  // Make sure to set totalDuration
      );

      if ((_isBreakTime && _autoStartBreak) || (!_isBreakTime && _autoStartWork)) {
        startTimer();
      }

      // Play completion sound
      try {
        await NotificationService.playSound(_isBreakTime);
      } catch (e) {
        print('Error playing completion sound: $e');
      }

      // Show notification
      try {
        final notificationTitle = _isBreakTime ? 'Break Time!' : 'Focus Session Complete';
        final notificationBody = _isBreakTime 
          ? 'Time for a ${_shortBreakDuration ~/ 60} minute break.'
          : 'Great job! Ready for another focus session?';
          
        await NotificationService.showNotification(
          notificationTitle,
          notificationBody,
          isBreakTime: _isBreakTime,
        );
      } catch (e) {
        print('Error showing completion notification: $e');
      }
    } catch (e) {
      print('Error completing session: $e');
    }
  }

  void toggleMode() {
    _isBreakTime = !_isBreakTime;
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      isBreak: _isBreakTime,
      currentDuration: Duration(
        seconds: _isBreakTime ? _shortBreakDuration : _workDuration
      ),
    );
  }

  void updateSettings({
    int? newWorkDuration,
    int? newShortBreakDuration,
    int? newLongBreakDuration,
    bool? newAutoStartBreak,
    bool? newAutoStartWork,
    int? newSessionsUntilLongBreak,
  }) {
    if (newWorkDuration != null) {
      _workDuration = newWorkDuration * 60;
      if (!state.isRunning && !state.isBreak) {
        _setNewDuration(_workDuration);
      }
    }
    if (newShortBreakDuration != null) {
      _shortBreakDuration = newShortBreakDuration * 60;
      if (!state.isRunning && state.isBreak && !state.isLongBreak) {
        _setNewDuration(_shortBreakDuration);
      }
    }
    if (newLongBreakDuration != null) {
      _longBreakDuration = newLongBreakDuration * 60;
      if (!state.isRunning && state.isBreak && state.isLongBreak) {
        _setNewDuration(_longBreakDuration);
      }
    }
    if (newAutoStartBreak != null) _autoStartBreak = newAutoStartBreak;
    if (newAutoStartWork != null) _autoStartWork = newAutoStartWork;
    if (newSessionsUntilLongBreak != null) _sessionsUntilLongBreak = newSessionsUntilLongBreak;
  }

  void resetTimer() {
    _timer?.cancel();
    _isBreakTime = false;  // Always reset to focus mode
    _isLongBreak = false;
    
    final newDuration = Duration(seconds: _workDuration);
    
    state = state.copyWith(
      isRunning: false,
      currentDuration: newDuration,
      totalDuration: newDuration,  // Ensure totalDuration is set
      isBreak: false,
      isLongBreak: false,
    );
    
    // Update desktop overlay when timer resets
    if (Platform.isWindows || Platform.isMacOS) {
      final minutes = state.currentDuration.inMinutes;
      final seconds = state.currentDuration.inSeconds % 60;
      final timerText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      DesktopOverlayService.updateSystemTray('Focus $timerText', false);
    }
  }

  void nextMode() {
    if (!state.isBreak) {
      // From Focus -> Short Break
      _isBreakTime = true;
      _isLongBreak = false;
      _setNewDuration(_shortBreakDuration);
    } else if (!state.isLongBreak) {
      // From Short Break -> Long Break
      _isLongBreak = true;
      _setNewDuration(_longBreakDuration);
    } else {
      // From Long Break -> Focus
      _isBreakTime = false;
      _isLongBreak = false;
      _setNewDuration(_workDuration);
    }
  }

  void previousMode() {
    if (state.isBreak && state.isLongBreak) {
      // From Long Break -> Short Break
      _isLongBreak = false;
      _setNewDuration(_shortBreakDuration);
    } else if (state.isBreak && !state.isLongBreak) {
      // From Short Break -> Focus
      _isBreakTime = false;
      _isLongBreak = false;
      _setNewDuration(_workDuration);
    } else {
      // From Focus -> Long Break
      _isBreakTime = true;
      _isLongBreak = true;
      _setNewDuration(_longBreakDuration);
    }
  }

  void _setNewDuration(int durationInSeconds) {
    _timer?.cancel();
    final newDuration = Duration(seconds: durationInSeconds);
    
    state = state.copyWith(
      isRunning: false,
      isBreak: _isBreakTime,
      isLongBreak: _isLongBreak,
      currentDuration: newDuration,
      totalDuration: newDuration,  // Ensure totalDuration is set
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    savePreferences();
    super.dispose();
  }
}