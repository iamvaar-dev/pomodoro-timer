import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/unique_id_service.dart';

/// Service for handling task synchronization with deduplication logic
class TaskSyncService {
  static final TaskSyncService _instance = TaskSyncService._internal();
  factory TaskSyncService() => _instance;
  TaskSyncService._internal();

  /// Merge local and remote tasks with comprehensive deduplication
  List<Task> mergeTasksWithDeduplication(
    List<Task> localTasks,
    List<Task> remoteTasks,
  ) {
    final Map<String, Task> mergedTasksMap = {};
    final Set<String> processedContentHashes = {};

    // First, process all tasks and group by content hash to detect duplicates
    final Map<String, List<Task>> tasksByContent = {};
    
    // Group local tasks by content
    for (final task in localTasks) {
      if (!task.isDeleted) {
        final contentHash = task.contentHash;
        tasksByContent.putIfAbsent(contentHash, () => []).add(task);
      }
    }

    // Group remote tasks by content
    for (final task in remoteTasks) {
      if (!task.isDeleted) {
        final contentHash = task.contentHash;
        tasksByContent.putIfAbsent(contentHash, () => []).add(task);
      }
    }

    // Process each content group
    for (final contentHash in tasksByContent.keys) {
      final tasksWithSameContent = tasksByContent[contentHash]!;
      
      if (tasksWithSameContent.length == 1) {
        // No duplicates, add the task as-is
        final task = tasksWithSameContent.first;
        mergedTasksMap[task.id] = task;
      } else {
        // Handle duplicates by selecting the best version
        final bestTask = _selectBestTaskFromDuplicates(tasksWithSameContent);
        mergedTasksMap[bestTask.id] = bestTask;
        
        debugPrint('Deduplication: Found ${tasksWithSameContent.length} duplicates for "${bestTask.title}", selected task with ID: ${bestTask.id}');
      }
      
      processedContentHashes.add(contentHash);
    }

    return mergedTasksMap.values.toList();
  }

  /// Select the best task from a list of duplicates
  Task _selectBestTaskFromDuplicates(List<Task> duplicates) {
    // Priority order:
    // 1. Task with Google ID (synced)
    // 2. Most recently modified
    // 3. Most recently created
    // 4. Completed task over incomplete
    
    duplicates.sort((a, b) {
      // Priority 1: Has Google ID (synced task)
      if (a.googleTaskId != null && b.googleTaskId == null) return -1;
      if (a.googleTaskId == null && b.googleTaskId != null) return 1;
      
      // Priority 2: Most recently modified
      if (a.lastModified != null && b.lastModified != null) {
        final modifiedComparison = b.lastModified!.compareTo(a.lastModified!);
        if (modifiedComparison != 0) return modifiedComparison;
      }
      if (a.lastModified != null && b.lastModified == null) return -1;
      if (a.lastModified == null && b.lastModified != null) return 1;
      
      // Priority 3: Most recently created
      final createdComparison = b.createdAt.compareTo(a.createdAt);
      if (createdComparison != 0) return createdComparison;
      
      // Priority 4: Completed task over incomplete
      if (a.isCompleted && !b.isCompleted) return -1;
      if (!a.isCompleted && b.isCompleted) return 1;
      
      // Fallback: lexicographic by ID
      return a.id.compareTo(b.id);
    });
    
    return duplicates.first;
  }

  /// Find potential duplicates in a task list
  List<List<Task>> findDuplicateGroups(List<Task> tasks) {
    final Map<String, List<Task>> tasksByContent = {};
    
    for (final task in tasks) {
      if (!task.isDeleted) {
        final contentHash = task.contentHash;
        tasksByContent.putIfAbsent(contentHash, () => []).add(task);
      }
    }
    
    return tasksByContent.values
        .where((group) => group.length > 1)
        .toList();
  }

  /// Remove duplicates from a task list, keeping the best version of each
  List<Task> removeDuplicates(List<Task> tasks) {
    final duplicateGroups = findDuplicateGroups(tasks);
    final Set<String> idsToRemove = {};
    
    for (final group in duplicateGroups) {
      final bestTask = _selectBestTaskFromDuplicates(group);
      for (final task in group) {
        if (task.id != bestTask.id) {
          idsToRemove.add(task.id);
        }
      }
    }
    
    return tasks.where((task) => !idsToRemove.contains(task.id)).toList();
  }

  /// Check if a task would be a duplicate if added to the existing list
  bool wouldBeDuplicate(Task newTask, List<Task> existingTasks) {
    return existingTasks.any((existing) => 
        !existing.isDeleted && newTask.hasSameContentAs(existing));
  }

  /// Find existing task with same content
  Task? findExistingTaskWithSameContent(Task newTask, List<Task> existingTasks) {
    try {
      return existingTasks.firstWhere((existing) => 
          !existing.isDeleted && newTask.hasSameContentAs(existing));
    } catch (e) {
      return null;
    }
  }
}