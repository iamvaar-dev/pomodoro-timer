import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskStorage {
  static const String _tasksKey = 'tasks';

  /// Save all tasks to storage
  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksKey, jsonEncode(tasksJson));
  }

  /// Load all tasks from storage
  static Future<List<Task>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksString = prefs.getString(_tasksKey);
      
      if (tasksString == null || tasksString.isEmpty) {
        return [];
      }
      
      final List<dynamic> tasksJson = jsonDecode(tasksString);
      return tasksJson.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  /// Clear all tasks from storage
  static Future<void> clearAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksKey);
  }

  /// Add a single task to storage
  static Future<void> addTask(Task task) async {
    final tasks = await loadTasks();
    tasks.add(task);
    await saveTasks(tasks);
  }

  /// Update a task in storage
  static Future<void> updateTask(Task updatedTask) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      tasks[index] = updatedTask;
      await saveTasks(tasks);
    }
  }

  /// Remove a task from storage
  static Future<void> removeTask(String taskId) async {
    final tasks = await loadTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await saveTasks(tasks);
  }

  /// Get tasks that need syncing
  static Future<List<Task>> getTasksNeedingSync() async {
    final tasks = await loadTasks();
    return tasks.where((task) => task.needsSync && !task.isDeleted).toList();
  }

  /// Get tasks by Google Task ID
  static Future<Task?> getTaskByGoogleId(String googleTaskId) async {
    final tasks = await loadTasks();
    try {
      return tasks.firstWhere((task) => task.googleTaskId == googleTaskId);
    } catch (e) {
      return null;
    }
  }

  /// Mark all tasks as synced
  static Future<void> markAllTasksAsSynced() async {
    final tasks = await loadTasks();
    final updatedTasks = tasks.map((task) => task.copyWith(
      needsSync: false,
      lastSynced: DateTime.now(),
    )).toList();
    await saveTasks(updatedTasks);
  }

  /// Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncString = prefs.getString('last_sync_time');
    if (lastSyncString != null) {
      return DateTime.parse(lastSyncString);
    }
    return null;
  }

  /// Save last sync time
  static Future<void> saveLastSyncTime(DateTime syncTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', syncTime.toIso8601String());
  }

  /// Clean up deleted tasks (remove them permanently)
  static Future<void> cleanupDeletedTasks() async {
    final tasks = await loadTasks();
    final activeTasks = tasks.where((task) => !task.isDeleted).toList();
    await saveTasks(activeTasks);
  }

  /// Get sync statistics
  static Future<Map<String, int>> getSyncStats() async {
    final tasks = await loadTasks();
    return {
      'total': tasks.length,
      'synced': tasks.where((task) => task.googleTaskId != null && !task.needsSync).length,
      'needsSync': tasks.where((task) => task.needsSync).length,
      'localOnly': tasks.where((task) => task.googleTaskId == null).length,
      'deleted': tasks.where((task) => task.isDeleted).length,
    };
  }
}