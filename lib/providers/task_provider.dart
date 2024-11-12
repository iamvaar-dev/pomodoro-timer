import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

class TaskNotifier extends StateNotifier<List<Task>> {
  TaskNotifier() : super([]);
  
  void addTask(String title) {
    final task = Task(title: title);
    state = [...state, task];
  }

  void toggleTask(String id) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(isCompleted: !task.isCompleted)
        else
          task,
    ];
  }

  void editTask(String id, String newTitle) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(title: newTitle)
        else
          task,
    ];
  }

  void removeTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  return TaskNotifier();
}); 