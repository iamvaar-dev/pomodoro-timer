import 'package:flutter/foundation.dart';
import 'package:googleapis/tasks/v1.dart' as tasks;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import 'task_storage.dart';
import 'google_auth_service.dart';
import 'task_sync_service.dart';
import 'unique_id_service.dart';

class GoogleTasksService {
  static final GoogleTasksService _instance = GoogleTasksService._internal();
  factory GoogleTasksService() => _instance;
  GoogleTasksService._internal();

  final GoogleAuthService _authService = GoogleAuthService();
  final TaskSyncService _syncService = TaskSyncService();
  tasks.TasksApi? _tasksApi;
  String? _defaultTaskListId;
  String? _lastError;

  /// Initialize the Google Tasks API
  Future<bool> initialize() async {
    try {
      final credentials = await _authService.getCredentials();
      if (credentials == null) {
        debugPrint('No credentials available for Google Tasks API');
        return false;
      }

      final client = authenticatedClient(http.Client(), credentials);
      _tasksApi = tasks.TasksApi(client);

      // Get the default task list
      await _getDefaultTaskList();
      return true;
    } catch (e) {
      debugPrint('Error initializing Google Tasks API: $e');
      return false;
    }
  }

  /// Get the default task list ID
  Future<void> _getDefaultTaskList() async {
    try {
      final taskLists = await _tasksApi!.tasklists.list();
      if (taskLists.items != null && taskLists.items!.isNotEmpty) {
        // Use the first task list (usually "My Tasks")
        _defaultTaskListId = taskLists.items!.first.id;
        debugPrint('Found default task list: ${taskLists.items!.first.title} (${_defaultTaskListId})');
        _lastError = null; // Clear any previous errors
      } else {
        // No task lists found, create a default one
        debugPrint('No task lists found, creating default task list');
        final newTaskList = tasks.TaskList()
          ..title = 'My Tasks';
        
        final createdTaskList = await _tasksApi!.tasklists.insert(newTaskList);
        _defaultTaskListId = createdTaskList.id;
        debugPrint('Created default task list: ${createdTaskList.title} (${_defaultTaskListId})');
        _lastError = null;
      }
    } catch (e) {
      debugPrint('Error getting/creating default task list: $e');
      final errorString = e.toString();
      if (errorString.contains('insufficient_scope') || errorString.contains('Access was denied')) {
        _lastError = 'insufficient_scope';
      } else {
        _lastError = 'error';
      }
    }
  }

  /// Sync local tasks with Google Tasks
  Future<List<Task>> syncTasks(List<Task> localTasks) async {
    try {
      if (!_authService.isSignedIn) {
        debugPrint('User not signed in, cannot sync tasks');
        return localTasks;
      }

      await _authService.refreshTokenIfNeeded();
      
      if (_tasksApi == null) {
        final initialized = await initialize();
        if (!initialized) return localTasks;
      }

      if (_defaultTaskListId == null) {
        debugPrint('No default task list found');
        return localTasks;
      }

      // Get remote tasks
      final remoteTasks = await _getRemoteTasks();
      
      // Merge local and remote tasks
      final mergedTasks = await _mergeTasks(localTasks, remoteTasks);
      
      // Save last sync time
      await TaskStorage.saveLastSyncTime(DateTime.now());
      
      // Clean up deleted tasks that have been synced
      await TaskStorage.cleanupDeletedTasks();
      
      return mergedTasks;
    } catch (e) {
      debugPrint('Error syncing tasks: $e');
      return localTasks; // Return local tasks if sync fails
    }
  }

  /// Get tasks from Google Tasks API
  Future<List<Task>> _getRemoteTasks() async {
    try {
      final response = await _tasksApi!.tasks.list(_defaultTaskListId!);
      final remoteTasks = <Task>[];

      if (response.items != null) {
        for (final googleTask in response.items!) {
          final task = _convertGoogleTaskToLocal(googleTask);
          if (task != null) {
            remoteTasks.add(task);
          }
        }
      }

      return remoteTasks;
    } catch (e) {
      debugPrint('Error getting remote tasks: $e');
      return [];
    }
  }

  /// Convert Google Task to local Task model
  Task? _convertGoogleTaskToLocal(tasks.Task googleTask, {String? localId}) {
    try {
      DateTime? dueDate;
      if (googleTask.due != null) {
        try {
          dueDate = DateTime.parse(googleTask.due!);
        } catch (e) {
          debugPrint('Error parsing due date: $e');
        }
      }

      DateTime? completedAt;
      if (googleTask.completed != null) {
        try {
          completedAt = DateTime.parse(googleTask.completed!);
        } catch (e) {
          debugPrint('Error parsing completed date: $e');
        }
      }

      DateTime? lastModified;
      if (googleTask.updated != null) {
        try {
          lastModified = DateTime.parse(googleTask.updated!);
        } catch (e) {
          debugPrint('Error parsing updated date: $e');
        }
      }

      return Task(
        id: localId ?? googleTask.id ?? '',
        title: googleTask.title ?? '',
        isCompleted: googleTask.status == 'completed',
        createdAt: lastModified ?? DateTime.now(),
        dueDate: dueDate,
        completedAt: completedAt,
        notes: googleTask.notes,
        googleTaskId: googleTask.id,
        lastSynced: DateTime.now(),
        lastModified: lastModified,
        isDeleted: googleTask.deleted ?? false,
        needsSync: false, // Just synced from Google
      );
    } catch (e) {
      debugPrint('Error converting Google Task: $e');
      return null;
    }
  }

  /// Convert local Task to Google Task
  tasks.Task _convertLocalTaskToGoogle(Task localTask, {bool forUpdate = false}) {
    final googleTask = tasks.Task();
    
    // Only set fields that are allowed for the operation
    if (forUpdate) {
      // For updates: include the task ID and fields that can be updated
      googleTask.id = localTask.googleTaskId; // CRITICAL: Must set ID for updates
      googleTask.title = localTask.title;
      googleTask.notes = localTask.notes;
      
      // Handle task completion status properly
      if (localTask.isCompleted) {
        googleTask.status = 'completed';
        // Set completion time when marking as completed
        if (localTask.completedAt != null) {
          googleTask.completed = localTask.completedAt!.toUtc().toIso8601String();
        } else {
          // If no completion time, use current time
          googleTask.completed = DateTime.now().toUtc().toIso8601String();
        }
      } else {
        googleTask.status = 'needsAction';
        // CRITICAL: Must explicitly set completed to null when unchecking
        // This is required by Google Tasks API when changing from completed to needsAction
        googleTask.completed = null;
      }
    } else {
      // For creation: include all relevant fields except id (never set id for creation)
      googleTask.title = localTask.title;
      googleTask.status = localTask.isCompleted ? 'completed' : 'needsAction';
      googleTask.notes = localTask.notes;
      
      // Set completion date if task is completed
      if (localTask.isCompleted && localTask.completedAt != null) {
        googleTask.completed = localTask.completedAt!.toUtc().toIso8601String();
      } else if (localTask.isCompleted) {
        // If completed but no completion time, use current time
        googleTask.completed = DateTime.now().toUtc().toIso8601String();
      }
    }

    // Set due date if available (Google Tasks only accepts date, not time)
    if (localTask.dueDate != null) {
      // Format as RFC 3339 date-only timestamp (Google Tasks expects this format)
      final dueDate = localTask.dueDate!;
      googleTask.due = '${dueDate.year.toString().padLeft(4, '0')}-'
          '${dueDate.month.toString().padLeft(2, '0')}-'
          '${dueDate.day.toString().padLeft(2, '0')}T00:00:00Z';
    }

    return googleTask;
  }

  /// Merge local and remote tasks with comprehensive deduplication
  Future<List<Task>> _mergeTasks(List<Task> localTasks, List<Task> remoteTasks) async {
    debugPrint('Starting merge: ${localTasks.length} local, ${remoteTasks.length} remote tasks');
    
    // Step 1: Handle deleted local tasks
    final activeLocalTasks = <Task>[];
    for (final localTask in localTasks) {
      if (localTask.isDeleted) {
        if (localTask.googleTaskId != null) {
          debugPrint('Deleting remote task: ${localTask.title}');
          await _deleteRemoteTask(localTask.googleTaskId!);
        }
        // Don't include deleted tasks in merge
      } else {
        activeLocalTasks.add(localTask);
      }
    }

    // Step 2: Separate tasks by sync status
    final Map<String, Task> tasksByGoogleId = {};
    final List<Task> localOnlyTasks = [];
    final List<Task> tasksNeedingUpload = [];

    for (final localTask in activeLocalTasks) {
      if (localTask.googleTaskId != null) {
        tasksByGoogleId[localTask.googleTaskId!] = localTask;
      } else if (localTask.needsSync) {
        tasksNeedingUpload.add(localTask);
      } else {
        localOnlyTasks.add(localTask);
      }
    }

    // Step 3: Process remote tasks and resolve conflicts
    final List<Task> processedTasks = [];
    final Set<String> processedGoogleIds = {};

    for (final remoteTask in remoteTasks) {
      if (remoteTask.isDeleted || remoteTask.googleTaskId == null) continue;

      final localTask = tasksByGoogleId[remoteTask.googleTaskId!];
      if (localTask != null) {
        // Conflict resolution
        final resolvedTask = await _resolveTaskConflict(localTask, remoteTask);
        processedTasks.add(resolvedTask);
        processedGoogleIds.add(remoteTask.googleTaskId!);
      } else {
        // Remote-only task
        processedTasks.add(remoteTask);
        processedGoogleIds.add(remoteTask.googleTaskId!);
      }
    }

    // Step 4: Upload new local tasks (check for duplicates first)
    for (final localTask in tasksNeedingUpload) {
      // Check if this task would be a duplicate
      if (!_syncService.wouldBeDuplicate(localTask, processedTasks)) {
        debugPrint('Uploading new task: ${localTask.title}');
        final uploadedTask = await _uploadTask(localTask);
        if (uploadedTask != null) {
          processedTasks.add(uploadedTask);
          if (uploadedTask.googleTaskId != null) {
            processedGoogleIds.add(uploadedTask.googleTaskId!);
          }
        } else {
          // Upload failed, keep local task
          processedTasks.add(localTask);
        }
      } else {
        debugPrint('Skipping duplicate task upload: ${localTask.title}');
        // Find the existing task and merge if needed
        final existingTask = _syncService.findExistingTaskWithSameContent(localTask, processedTasks);
        if (existingTask != null && existingTask.googleTaskId == null && localTask.googleTaskId != null) {
          // Update existing task with Google ID
          final updatedTask = existingTask.copyWith(
            googleTaskId: localTask.googleTaskId,
            lastSynced: localTask.lastSynced,
            needsSync: false,
          );
          final index = processedTasks.indexWhere((t) => t.id == existingTask.id);
          if (index != -1) {
            processedTasks[index] = updatedTask;
          }
        }
      }
    }

    // Step 5: Add local-only tasks
    processedTasks.addAll(localOnlyTasks);

    // Step 6: Final deduplication pass
    final deduplicatedTasks = _syncService.removeDuplicates(processedTasks);
    
    debugPrint('Merge complete: ${deduplicatedTasks.length} final tasks');
    return deduplicatedTasks;
  }

  /// Resolve conflicts between local and remote tasks
  Future<Task> _resolveTaskConflict(Task localTask, Task remoteTask) async {
    // Compare last modified timestamps
    final localModified = localTask.lastModified ?? localTask.createdAt;
    final remoteModified = remoteTask.lastModified ?? remoteTask.createdAt;

    if (localModified.isAfter(remoteModified)) {
      // Local is newer, update remote
      // Ensure we preserve the Google Task ID from the remote task
      final taskToUpdate = localTask.copyWith(
        googleTaskId: remoteTask.googleTaskId,
      );
      
      try {
        await _updateRemoteTask(taskToUpdate);
        return taskToUpdate.copyWith(
          lastSynced: DateTime.now(),
          needsSync: false,
        );
      } catch (e) {
        debugPrint('Failed to update remote task: $e');
        // Return local task with preserved Google ID but marked as needing sync
        return taskToUpdate.copyWith(needsSync: true);
      }
    } else {
      // Remote is newer or equal, use remote data but preserve local ID
      return remoteTask.copyWith(
        id: localTask.id,
        lastSynced: DateTime.now(),
        needsSync: false,
      );
    }
  }

  /// Delete a task from Google Tasks
  Future<void> _deleteRemoteTask(String googleTaskId) async {
    try {
      if (_defaultTaskListId == null || _tasksApi == null) return;
      
      await _tasksApi!.tasks.delete(_defaultTaskListId!, googleTaskId);
      debugPrint('Deleted remote task: $googleTaskId');
    } catch (e) {
      debugPrint('Error deleting remote task: $e');
    }
  }

  /// Upload a new task to Google Tasks
  Future<Task?> _uploadTask(Task localTask) async {
    try {
      if (_defaultTaskListId == null || _tasksApi == null) return null;
      
      final googleTask = _convertLocalTaskToGoogle(localTask);
      final response = await _tasksApi!.tasks.insert(googleTask, _defaultTaskListId!);
      
      return localTask.copyWith(
        googleTaskId: response.id,
        lastSynced: DateTime.now(),
        lastModified: DateTime.now(),
        needsSync: false,
      );
    } catch (e) {
      debugPrint('Error uploading task: $e');
      return null;
    }
  }

  /// Update a remote task
  Future<void> _updateRemoteTask(Task localTask) async {
    try {
      // Validate required fields
      if (localTask.googleTaskId == null) {
        debugPrint('Cannot update task: missing Google Task ID for task "${localTask.title}"');
        return;
      }
      
      if (_defaultTaskListId == null || _tasksApi == null) {
        debugPrint('Cannot update task: Google Tasks API not initialized');
        return;
      }
      
      final googleTask = _convertLocalTaskToGoogle(localTask, forUpdate: true);
      
      // Debug logging to see what data we're sending
      debugPrint('Updating task ${localTask.googleTaskId} with data:');
      debugPrint('  - title: ${googleTask.title}');
      debugPrint('  - status: ${googleTask.status}');
      debugPrint('  - notes: ${googleTask.notes}');
      debugPrint('  - due: ${googleTask.due}');
      debugPrint('  - completed: ${googleTask.completed}');
      
      await _tasksApi!.tasks.update(
        googleTask, 
        _defaultTaskListId!, 
        localTask.googleTaskId!,
      );
      debugPrint('Updated remote task: ${localTask.googleTaskId}');
    } catch (e) {
      debugPrint('Error updating remote task: $e');
    }
  }

  /// Create a new task and sync to Google Tasks
  Future<Task?> createTask({
    required String title,
    String? notes,
    DateTime? dueDate,
  }) async {
    try {
      // Generate a proper UUID for the task
      final taskId = UniqueIdService.generateTaskId();
      
      final newTask = Task(
        id: taskId,
        title: title,
        notes: notes,
        dueDate: dueDate,
        isCompleted: false,
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        needsSync: true,
      );

      // Upload to Google Tasks if connected
      if (canSync) {
        return await _uploadTask(newTask);
      }

      return newTask;
    } catch (e) {
      debugPrint('Error creating task: $e');
      return null;
    }
  }

  /// Update an existing task and sync changes
  Future<Task?> updateTask(Task task, {
    String? title,
    String? notes,
    DateTime? dueDate,
    bool? isCompleted,
  }) async {
    try {
      final updatedTask = task.copyWith(
        title: title ?? task.title,
        notes: notes ?? task.notes,
        dueDate: dueDate ?? task.dueDate,
        isCompleted: isCompleted ?? task.isCompleted,
        completedAt: (isCompleted == true && task.completedAt == null) 
            ? DateTime.now() 
            : (isCompleted == false ? null : task.completedAt),
        lastModified: DateTime.now(),
        needsSync: true,
      );

      // Update on Google Tasks if connected and has Google ID
      if (canSync && updatedTask.googleTaskId != null) {
        await _updateRemoteTask(updatedTask);
        return updatedTask.copyWith(
          lastSynced: DateTime.now(),
          needsSync: false,
        );
      }

      return updatedTask;
    } catch (e) {
      debugPrint('Error updating task: $e');
      return null;
    }
  }

  /// Mark a task as completed
  Future<Task?> completeTask(Task task) async {
    return await updateTask(task, isCompleted: true);
  }

  /// Mark a task as incomplete
  Future<Task?> uncompleteTask(Task task) async {
    return await updateTask(task, isCompleted: false);
  }

  /// Delete a task (mark as deleted and remove from Google Tasks)
  Future<bool> deleteTask(Task task) async {
    try {
      // Delete from Google Tasks if connected
      if (canSync && task.googleTaskId != null) {
        await _deleteRemoteTask(task.googleTaskId!);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting task: $e');
      return false;
    }
  }

  /// Check if sync is available
  bool get canSync => _authService.isSignedIn && _tasksApi != null;

  /// Get sync status
  String get syncStatus {
    if (!_authService.isSignedIn) return 'Not signed in';
    if (_tasksApi == null) return 'Not initialized';
    if (_lastError != null) return _lastError!;
    if (_defaultTaskListId == null) return 'No task list found';
    return 'Ready to sync';
  }

  /// Force refresh the API connection
  Future<void> refreshConnection() async {
    _tasksApi = null;
    _defaultTaskListId = null;
    _lastError = null;
    await initialize();
  }

  /// Clear any stored errors
  void clearErrors() {
    _lastError = null;
  }
}