import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_stats.dart';

class StatsStorage {
  static const String _statsKey = 'daily_stats';
  
  static Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
  }

  static Future<SessionStats> loadStats(String period) async {
    final stats = await getAllStats();
    final today = DateTime.now();
    
    switch (period) {
      case 'daily':
        return getTodayStats();
      case 'weekly':
        return _getWeekStats(stats, today);
      case 'monthly':
        return _getMonthStats(stats, today);
      case 'yearly':
        return _getYearStats(stats, today);
      default:
        return getTodayStats();
    }
  }

  static Future<List<SessionStats>> getAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? statsJson = prefs.getString(_statsKey);
    
    if (statsJson == null) return [];
    
    final List<dynamic> statsList = json.decode(statsJson);
    return statsList.map((json) => SessionStats.fromJson(json)).toList();
  }

  static Future<void> saveSession(Duration sessionDuration) async {
    try {
      final stats = await getAllStats();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      // Find existing today's stats
      final existingTodayStats = stats.firstWhere(
        (stat) => stat.date.year == todayStart.year && 
                  stat.date.month == todayStart.month && 
                  stat.date.day == todayStart.day,
        orElse: () => SessionStats(
          date: todayStart,
          focusMinutes: 0,
          completedSessions: 0,
          focusSessions: [],
        ),
      );
      
      // Create updated stats
      final updatedTodayStats = existingTodayStats.copyWith(
        focusMinutes: existingTodayStats.focusMinutes + sessionDuration.inMinutes,
        completedSessions: existingTodayStats.completedSessions + 1,
        focusSessions: [...existingTodayStats.focusSessions, sessionDuration],
      );
      
      // Remove old entry and add updated one
      stats.removeWhere((stat) => 
        stat.date.year == todayStart.year && 
        stat.date.month == todayStart.month && 
        stat.date.day == todayStart.day
      );
      stats.add(updatedTodayStats);
      
      // Sort stats by date (newest first)
      stats.sort((a, b) => b.date.compareTo(a.date));
      
      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statsKey, json.encode(stats.map((s) => s.toJson()).toList()));
      
      print('Session saved - Sessions: ${updatedTodayStats.completedSessions}, Minutes: ${updatedTodayStats.focusMinutes}');
    } catch (e) {
      print('Error saving session stats: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  static Future<SessionStats> getTodayStats() async {
    try {
      final stats = await getAllStats();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      return stats.firstWhere(
        (stat) => stat.date.year == todayStart.year && 
                  stat.date.month == todayStart.month && 
                  stat.date.day == todayStart.day,
        orElse: () => SessionStats(
          date: todayStart,
          focusMinutes: 0,
          completedSessions: 0,
          focusSessions: [],
        ),
      );
    } catch (e) {
      print('Error getting today stats: $e');
      // Return empty stats on error
      return SessionStats(
        date: DateTime.now(),
        focusMinutes: 0,
        completedSessions: 0,
        focusSessions: [],
      );
    }
  }

  static Future<SessionStats> _getWeekStats(List<SessionStats> stats, DateTime date) async {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    return _aggregateStats(
      stats.where((stat) => 
        stat.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        stat.date.isBefore(weekEnd)
      ).toList(),
      weekStart,
    );
  }

  static Future<SessionStats> _getMonthStats(List<SessionStats> stats, DateTime date) async {
    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 0);
    
    return _aggregateStats(
      stats.where((stat) => 
        stat.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
        stat.date.isBefore(monthEnd.add(const Duration(days: 1)))
      ).toList(),
      monthStart,
    );
  }

  static Future<SessionStats> _getYearStats(List<SessionStats> stats, DateTime date) async {
    final yearStart = DateTime(date.year, 1, 1);
    final yearEnd = DateTime(date.year + 1, 1, 0);
    
    return _aggregateStats(
      stats.where((stat) => 
        stat.date.isAfter(yearStart.subtract(const Duration(days: 1))) &&
        stat.date.isBefore(yearEnd.add(const Duration(days: 1)))
      ).toList(),
      yearStart,
    );
  }

  static SessionStats _aggregateStats(List<SessionStats> stats, DateTime date) {
    if (stats.isEmpty) {
      return SessionStats(
        date: date,
        focusMinutes: 0,
        completedSessions: 0,
        focusSessions: [],
      );
    }

    final totalMinutes = stats.fold(0, (sum, stat) => sum + stat.focusMinutes);
    final totalSessions = stats.fold(0, (sum, stat) => sum + stat.completedSessions);
    final allSessions = stats.expand((stat) => stat.focusSessions).toList();

    return SessionStats(
      date: date,
      focusMinutes: totalMinutes,
      completedSessions: totalSessions,
      focusSessions: allSessions,
    );
  }

  static Future<void> checkAndResetDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString('lastResetDate');
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (lastResetDate != today) {
      // It's a new day, reset the stats
      final stats = await getAllStats();
      final todayStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      
      // Remove any incorrect entries for today
      stats.removeWhere((stat) => stat.date.year == todayStart.year && 
                                stat.date.month == todayStart.month && 
                                stat.date.day == todayStart.day);
      
      // Save cleaned stats
      await prefs.setString(_statsKey, json.encode(stats.map((s) => s.toJson()).toList()));
      await prefs.setString('lastResetDate', today);
    }
  }
} 