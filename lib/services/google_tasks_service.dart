import 'package:flutter/foundation.dart';
import 'package:googleapis/tasks/v1.dart' as tasks;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import 'google_auth_service.dart';

class GoogleTasksService {
  static final GoogleTasksService _instance = GoogleTasksService._internal();
  factory GoogleTasksService() => _instance;
  GoogleTasksService._internal();

  final GoogleAuthService _authService = GoogleAuthService();
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
        _lastError = null; // Clear any previous errors
      }
    } catch (e) {
      debugPrint('Error getting default task list: $e');
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
  Task? _convertGoogleTaskToLocal(tasks.Task googleTask) {
    try {
      return Task(
        id: googleTask.id ?? '',
        title: googleTask.title ?? '',
        isCompleted: googleTask.status == 'completed',
        createdAt: googleTask.updated != null 
            ? DateTime.parse(googleTask.updated!) 
            : DateTime.now(),
        googleTaskId: googleTask.id,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error converting Google Task: $e');
      return null;
    }
  }

  /// Convert local Task to Google Task
  tasks.Task _convertLocalTaskToGoogle(Task localTask) {
    return tasks.Task(
      id: localTask.googleTaskId,
      title: localTask.title,
      status: localTask.isCompleted ? 'completed' : 'needsAction',
      updated: localTask.lastSynced?.toIso8601String(),
    );
  }

  /// Merge local and remote tasks
  Future<List<Task>> _mergeTasks(List<Task> localTasks, List<Task> remoteTasks) async {
    final mergedTasks = <Task>[];
    final processedGoogleIds = <String>{};

    // Process local tasks
    for (final localTask in localTasks) {
      if (localTask.googleTaskId != null) {
        // Find corresponding remote task
        final remoteTask = remoteTasks.firstWhere(
          (t) => t.googleTaskId == localTask.googleTaskId,
          orElse: () => Task(id: '', title: ''),
        );

        if (remoteTask.id.isNotEmpty) {
          // Task exists remotely, merge based on last modified
          final mergedTask = _mergeTaskConflict(localTask, remoteTask);
          mergedTasks.add(mergedTask);
          processedGoogleIds.add(localTask.googleTaskId!);
        } else {
          // Local task doesn't exist remotely, upload it
          final uploadedTask = await _uploadTask(localTask);
          mergedTasks.add(uploadedTask ?? localTask);
          if (uploadedTask?.googleTaskId != null) {
            processedGoogleIds.add(uploadedTask!.googleTaskId!);
          }
        }
      } else {
        // New local task, upload to Google
        final uploadedTask = await _uploadTask(localTask);
        mergedTasks.add(uploadedTask ?? localTask);
        if (uploadedTask?.googleTaskId != null) {
          processedGoogleIds.add(uploadedTask!.googleTaskId!);
        }
      }
    }

    // Add remote tasks that don't exist locally
    for (final remoteTask in remoteTasks) {
      if (remoteTask.googleTaskId != null && 
          !processedGoogleIds.contains(remoteTask.googleTaskId)) {
        mergedTasks.add(remoteTask);
      }
    }

    return mergedTasks;
  }

  /// Merge conflicting tasks based on last modified time
  Task _mergeTaskConflict(Task localTask, Task remoteTask) {
    // Use the most recently modified task
    final localModified = localTask.lastSynced ?? localTask.createdAt;
    final remoteModified = remoteTask.lastSynced ?? remoteTask.createdAt;

    if (localModified.isAfter(remoteModified)) {
      // Local is newer, update remote
      _updateRemoteTask(localTask);
      return localTask.copyWith(lastSynced: DateTime.now());
    } else {
      // Remote is newer, use remote data
      return remoteTask.copyWith(
        id: localTask.id, // Keep local ID for database consistency
        lastSynced: DateTime.now(),
      );
    }
  }

  /// Upload a new task to Google Tasks
  Future<Task?> _uploadTask(Task localTask) async {
    try {
      final googleTask = _convertLocalTaskToGoogle(localTask);
      final response = await _tasksApi!.tasks.insert(googleTask, _defaultTaskListId!);
      
      return localTask.copyWith(
        googleTaskId: response.id,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error uploading task: $e');
      return null;
    }
  }

  /// Update a remote task
  Future<void> _updateRemoteTask(Task localTask) async {
    try {
      if (localTask.googleTaskId == null) return;
      
      final googleTask = _convertLocalTaskToGoogle(localTask);
      await _tasksApi!.tasks.update(
        googleTask, 
        _defaultTaskListId!, 
        localTask.googleTaskId!,
      );
    } catch (e) {
      debugPrint('Error updating remote task: $e');
    }
  }

  /// Delete a task from Google Tasks
  Future<bool> deleteTask(String googleTaskId) async {
    try {
      if (_defaultTaskListId == null || _tasksApi == null) return false;
      
      await _tasksApi!.tasks.delete(_defaultTaskListId!, googleTaskId);
      return true;
    } catch (e) {
      debugPrint('Error deleting remote task: $e');
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