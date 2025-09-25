import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/task_state.dart';
import '../services/task_storage.dart';
import '../services/google_auth_service.dart';
import '../services/google_tasks_service.dart';

class TaskNotifier extends StateNotifier<TaskState> {
  final GoogleAuthService _authService = GoogleAuthService();
  final GoogleTasksService _tasksService = GoogleTasksService();

  TaskNotifier() : super(const TaskState(
    tasks: [],
    isSignedIn: false,
    isSyncing: false,
    syncStatus: 'Not synced',
  )) {
    _loadTasks();
    _initializeGoogleServices();
  }

  bool get isSyncing => state.isSyncing;
  String get syncStatus => state.syncStatus;
  bool get isSignedIn => state.isSignedIn;
  String? get userEmail => state.userEmail;
  
  /// Initialize Google services
  Future<void> _initializeGoogleServices() async {
    try {
      await _authService.initialize();
      _updateSyncStatus();
    } catch (e) {
      debugPrint('Error initializing Google services: $e');
      state = state.copyWith(syncStatus: 'Initialization failed');
    }
  }

  /// Load tasks from storage on initialization
  Future<void> _loadTasks() async {
    try {
      final tasks = await TaskStorage.loadTasks();
      state = state.copyWith(tasks: tasks);
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  /// Update sync status
  void _updateSyncStatus() {
    String newSyncStatus;
    if (!_authService.isSignedIn) {
      newSyncStatus = 'Not signed in';
    } else if (_tasksService.canSync) {
      newSyncStatus = 'Ready to sync';
    } else {
      newSyncStatus = _tasksService.syncStatus;
    }
    
    state = state.copyWith(
      isSignedIn: _authService.isSignedIn,
      userEmail: _authService.userEmail,
      syncStatus: newSyncStatus,
    );
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      final account = await _authService.signIn();
      if (account != null) {
        _updateSyncStatus();
        // Auto-sync after successful sign-in
        await syncWithGoogle();
        return true;
      }
      state = state.copyWith(syncStatus: 'Sign-in canceled');
      return false;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      state = state.copyWith(syncStatus: _authService.getAuthErrorMessage(e));
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOutFromGoogle() async {
    try {
      await _authService.signOut();
      _updateSyncStatus();
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }
  }

  /// Re-authenticate with Google to get updated scopes
  Future<bool> reAuthenticateWithGoogle() async {
    try {
      state = state.copyWith(isSyncing: true, syncStatus: 'Re-authenticating...');
      
      // Clear any previous errors
      _tasksService.clearErrors();
      
      final account = await _authService.reAuthenticate();
      if (account != null) {
        // Refresh the tasks service connection
        await _tasksService.refreshConnection();
        _updateSyncStatus();
        // Auto-sync after successful re-authentication
        await syncWithGoogle();
        return true;
      }
      state = state.copyWith(syncStatus: 'Re-authentication canceled');
      return false;
    } catch (e) {
      debugPrint('Error re-authenticating with Google: $e');
      state = state.copyWith(syncStatus: _authService.getAuthErrorMessage(e));
      return false;
    }
  }

  /// Sync tasks with Google Tasks
  Future<void> syncWithGoogle() async {
    if (state.isSyncing || !_authService.isSignedIn) return;

    try {
      state = state.copyWith(isSyncing: true, syncStatus: 'Syncing...');
      
      final syncedTasks = await _tasksService.syncTasks(state.tasks);
      await TaskStorage.saveTasks(syncedTasks);
      
      state = state.copyWith(
        tasks: syncedTasks,
        isSyncing: false,
        syncStatus: 'Synced at ${DateTime.now().toString().substring(11, 16)}',
      );
    } catch (e) {
      debugPrint('Error syncing with Google: $e');
      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Sync failed',
      );
    }
  }

  /// Add a new task
  Future<void> addTask(String title) async {
    try {
      final task = Task(title: title);
      final newTasks = [...state.tasks, task];
      state = state.copyWith(tasks: newTasks);
      await TaskStorage.saveTasks(newTasks);
      
      // Auto-sync if signed in
      if (_authService.isSignedIn && !state.isSyncing) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  /// Toggle task completion status
  Future<void> toggleTask(String id) async {
    try {
      final newTasks = [
        for (final task in state.tasks)
          if (task.id == id)
            task.copyWith(isCompleted: !task.isCompleted)
          else
            task,
      ];
      state = state.copyWith(tasks: newTasks);
      await TaskStorage.saveTasks(newTasks);
      
      // Auto-sync if signed in
      if (_authService.isSignedIn && !state.isSyncing) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  /// Edit task title
  Future<void> editTask(String id, String newTitle) async {
    try {
      final newTasks = [
        for (final task in state.tasks)
          if (task.id == id)
            task.copyWith(title: newTitle)
          else
            task,
      ];
      state = state.copyWith(tasks: newTasks);
      await TaskStorage.saveTasks(newTasks);
      
      // Auto-sync if signed in
      if (_authService.isSignedIn && !state.isSyncing) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error editing task: $e');
    }
  }

  /// Remove a task
  Future<void> removeTask(String id) async {
    try {
      // Find the task to get its Google Task ID for deletion
      final taskToRemove = state.tasks.firstWhere(
        (task) => task.id == id,
        orElse: () => Task(title: ''),
      );
      
      final newTasks = state.tasks.where((task) => task.id != id).toList();
      state = state.copyWith(tasks: newTasks);
      await TaskStorage.saveTasks(newTasks);
      
      // Delete from Google Tasks if it has a Google Task ID
      if (_authService.isSignedIn && taskToRemove.googleTaskId != null) {
        await _tasksService.deleteTask(taskToRemove.googleTaskId!);
      }
      
      // Auto-sync if signed in
      if (_authService.isSignedIn && !state.isSyncing) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error removing task: $e');
    }
  }

  /// Refresh tasks from storage and sync if signed in
  Future<void> refreshTasks() async {
    await _loadTasks();
    if (_authService.isSignedIn && !state.isSyncing) {
      await syncWithGoogle();
    }
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier();
});

// Provider for tasks list
final tasksProvider = Provider<List<Task>>((ref) {
  return ref.watch(taskProvider).tasks;
});

// Provider for sync status
final syncStatusProvider = Provider<String>((ref) {
  return ref.watch(taskProvider).syncStatus;
});

// Provider for sync loading state
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(taskProvider).isSyncing;
});

// Provider for Google sign-in status
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(taskProvider).isSignedIn;
});

// Provider for user email
final userEmailProvider = Provider<String?>((ref) {
  return ref.watch(taskProvider).userEmail;
});