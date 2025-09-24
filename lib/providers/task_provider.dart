import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/task_storage.dart';

class TaskNotifier extends StateNotifier<List<Task>> {
  TaskNotifier() : super([]) {
    _loadTasks();
  }
  
  /// Load tasks from storage on initialization
  Future<void> _loadTasks() async {
    try {
      final tasks = await TaskStorage.loadTasks();
      state = tasks;
    } catch (e) {
      print('Error loading tasks: $e');
    }
  }

  /// Add a new task
  Future<void> addTask(String title) async {
    try {
      final task = Task(title: title);
      state = [...state, task];
      await TaskStorage.saveTasks(state);
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  /// Toggle task completion status
  Future<void> toggleTask(String id) async {
    try {
      state = [
        for (final task in state)
          if (task.id == id)
            task.copyWith(isCompleted: !task.isCompleted)
          else
            task,
      ];
      await TaskStorage.saveTasks(state);
    } catch (e) {
      print('Error toggling task: $e');
    }
  }

  /// Edit task title
  Future<void> editTask(String id, String newTitle) async {
    try {
      state = [
        for (final task in state)
          if (task.id == id)
            task.copyWith(title: newTitle)
          else
            task,
      ];
      await TaskStorage.saveTasks(state);
    } catch (e) {
      print('Error editing task: $e');
    }
  }

  /// Remove a task
  Future<void> removeTask(String id) async {
    try {
      state = state.where((task) => task.id != id).toList();
      await TaskStorage.saveTasks(state);
    } catch (e) {
      print('Error removing task: $e');
    }
  }

  /// Refresh tasks from storage
  Future<void> refreshTasks() async {
    await _loadTasks();
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  return TaskNotifier();
});