import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/task_state.dart';
import '../services/task_storage.dart';
import '../services/google_auth_service.dart';
import '../services/google_tasks_service.dart';
import '../services/task_sync_service.dart';

class TaskNotifier extends StateNotifier<TaskState> {
  final GoogleAuthService _authService = GoogleAuthService();
  final GoogleTasksService _tasksService = GoogleTasksService();
  final TaskSyncService _syncService = TaskSyncService();
  Timer? _periodicSyncTimer;
  StreamSubscription? _authStateSubscription;

  TaskNotifier() : super(const TaskState(
    tasks: [],
    isSignedIn: false,
    isSyncing: false,
    syncStatus: 'Not synced',
  )) {
    _loadTasks();
    _initializeGoogleServices();
    _startPeriodicSync();
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    _authStateSubscription?.cancel();
    _authService.dispose();
    super.dispose();
  }

  bool get isSyncing => state.isSyncing;
  String get syncStatus => state.syncStatus;
  bool get isSignedIn => state.isSignedIn;
  String? get userEmail => state.userEmail;
  
  /// Initialize Google services
  Future<void> _initializeGoogleServices() async {
    try {
      await _authService.initialize();
      
      // Listen to authentication state changes
      _authStateSubscription = _authService.authStateChanges.listen((isSignedIn) async {
        await _updateSyncStatus();
        if (isSignedIn) {
          // Auto-sync when user signs in
          Future.delayed(const Duration(milliseconds: 500), () {
            syncWithGoogle();
          });
        }
      });
      
      await _updateSyncStatus();
    } catch (e) {
      debugPrint('Error initializing Google services: $e');
      state = state.copyWith(syncStatus: 'Initialization failed');
    }
  }

  /// Load tasks from storage on initialization
  Future<void> _loadTasks() async {
    try {
      final tasks = await TaskStorage.loadTasks();
      
      // Remove any duplicates that might exist in storage
      final deduplicatedTasks = _syncService.removeDuplicates(tasks);
      
      // Save back if duplicates were found
      if (deduplicatedTasks.length != tasks.length) {
        await TaskStorage.saveTasks(deduplicatedTasks);
        debugPrint('Removed ${tasks.length - deduplicatedTasks.length} duplicate tasks during load');
      }
      
      state = state.copyWith(tasks: deduplicatedTasks);
      
      // Trigger initial sync if user is signed in (check both current and stored state)
      final isSignedIn = _authService.isSignedIn || await _authService.isSignedInStored;
      if (isSignedIn && _tasksService.canSync) {
        // Use a small delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          syncWithGoogle();
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  /// Update sync status
  Future<void> _updateSyncStatus() async {
    String newSyncStatus;
    bool isSignedIn = _authService.isSignedIn;
    String? userEmail = _authService.userEmail;
    
    // If current user is null, check stored state
    if (!isSignedIn) {
      isSignedIn = await _authService.isSignedInStored;
      userEmail = await _authService.userEmailStored;
    }
    
    if (!isSignedIn) {
      newSyncStatus = 'Not signed in';
    } else if (_tasksService.canSync) {
      newSyncStatus = 'Ready to sync';
    } else {
      newSyncStatus = _tasksService.syncStatus;
    }
    
    state = state.copyWith(
      isSignedIn: isSignedIn,
      userEmail: userEmail,
      syncStatus: newSyncStatus,
    );
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    // Cancel any existing timer
    _periodicSyncTimer?.cancel();
    
    // Start a new timer that syncs every minute
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Only sync if signed in and not already syncing
      if (_authService.isSignedIn && !state.isSyncing) {
        debugPrint('Performing periodic sync...');
        syncWithGoogle();
      }
    });
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      final account = await _authService.signIn();
      if (account != null) {
        await _updateSyncStatus();
        // Restart periodic sync for signed-in state
        _startPeriodicSync();
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
      await _updateSyncStatus();
      // Restart periodic sync for signed-out state (will be inactive)
      _startPeriodicSync();
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
        await _updateSyncStatus();
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
      
      // Remove any duplicates that might have been introduced during sync
      final deduplicatedTasks = _syncService.removeDuplicates(syncedTasks);
      
      await TaskStorage.saveTasks(deduplicatedTasks);
      
      if (deduplicatedTasks.length != syncedTasks.length) {
        debugPrint('Removed ${syncedTasks.length - deduplicatedTasks.length} duplicate tasks after sync');
      }
      
      state = state.copyWith(
        tasks: deduplicatedTasks,
        isSyncing: false,
        syncStatus: 'Synced at ${DateTime.now().toString().substring(11, 16)}',
      );
    } catch (e) {
      debugPrint('Error syncing with Google: $e');
      // Use the specific error from the tasks service if available
      final errorMessage = _tasksService.syncStatus.contains('insufficient_scope') 
          ? _tasksService.syncStatus 
          : 'Sync failed';
      state = state.copyWith(
        isSyncing: false,
        syncStatus: errorMessage,
      );
    }
  }

  /// Add a new task
  Future<void> addTask(String title, {String? notes, DateTime? dueDate}) async {
    try {
      // Create a temporary task to check for duplicates
      final tempTask = Task(
        title: title,
        notes: notes,
        dueDate: dueDate,
        needsSync: _authService.isSignedIn,
      );
      
      // Check if this would be a duplicate
      if (_syncService.wouldBeDuplicate(tempTask, state.tasks)) {
        debugPrint('Duplicate task detected, not creating: $title');
        return;
      }
      
      Task? newTask;
      
      // Use Google Tasks service if signed in and can sync
      if (_authService.isSignedIn && _tasksService.canSync) {
        newTask = await _tasksService.createTask(
          title: title,
          notes: notes,
          dueDate: dueDate,
        );
      }
      
      // Fallback to local task creation
      newTask ??= tempTask;
      
      final newTasks = [...state.tasks, newTask];
      
      // Remove any duplicates that might have been introduced
      final deduplicatedTasks = _syncService.removeDuplicates(newTasks);
      
      state = state.copyWith(tasks: deduplicatedTasks);
      await TaskStorage.saveTasks(deduplicatedTasks);
      
      // Auto-sync if signed in and task wasn't already synced
      if (_authService.isSignedIn && !state.isSyncing && newTask.needsSync) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  /// Toggle task completion status
  Future<void> toggleTaskCompletion(String taskId) async {
    try {
      final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) return;

      final task = state.tasks[taskIndex];
      final updatedTask = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
        lastModified: DateTime.now(),
        needsSync: true,
      );

      final newTasks = [...state.tasks];
      newTasks[taskIndex] = updatedTask;
      
      // Remove any duplicates that might exist
      final deduplicatedTasks = _syncService.removeDuplicates(newTasks);
      
      state = state.copyWith(tasks: deduplicatedTasks);
      await TaskStorage.saveTasks(deduplicatedTasks);
      
      // Auto-sync if signed in
      if (_authService.isSignedIn && !state.isSyncing) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error toggling task completion: $e');
    }
  }

  /// Edit task details
  Future<void> editTask(String id, {String? title, String? notes, DateTime? dueDate}) async {
    try {
      final taskIndex = state.tasks.indexWhere((task) => task.id == id);
      if (taskIndex == -1) return;
      
      final originalTask = state.tasks[taskIndex];
      
      final updatedTask = originalTask.copyWith(
        title: title ?? originalTask.title,
        notes: notes ?? originalTask.notes,
        dueDate: dueDate ?? originalTask.dueDate,
        lastModified: DateTime.now(),
        needsSync: true,
      );
      
      final newTasks = [...state.tasks];
      newTasks[taskIndex] = updatedTask;
      
      // Remove any duplicates that might exist
      final deduplicatedTasks = _syncService.removeDuplicates(newTasks);
      
      state = state.copyWith(tasks: deduplicatedTasks);
      await TaskStorage.saveTasks(deduplicatedTasks);
      
      // Auto-sync if signed in
      if (_authService.isSignedIn && !state.isSyncing) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error editing task: $e');
    }
  }

  /// Complete a task
  Future<void> completeTask(String id) async {
    try {
      final taskIndex = state.tasks.indexWhere((task) => task.id == id);
      if (taskIndex == -1) return;
      
      final originalTask = state.tasks[taskIndex];
      if (originalTask.isCompleted) return; // Already completed
      
      Task? updatedTask;
      
      // Use Google Tasks service if signed in and can sync
      if (_authService.isSignedIn && _tasksService.canSync) {
        updatedTask = await _tasksService.completeTask(originalTask);
      }
      
      // Fallback to local update
      updatedTask ??= originalTask.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
        lastModified: DateTime.now(),
        needsSync: _authService.isSignedIn,
      );
      
      final newTasks = [...state.tasks];
      newTasks[taskIndex] = updatedTask;
      
      state = state.copyWith(tasks: newTasks);
      await TaskStorage.saveTasks(newTasks);
      
      // Auto-sync if signed in and task wasn't already synced
      if (_authService.isSignedIn && !state.isSyncing && updatedTask.needsSync) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error completing task: $e');
    }
  }

  /// Uncomplete a task
  Future<void> uncompleteTask(String id) async {
    try {
      final taskIndex = state.tasks.indexWhere((task) => task.id == id);
      if (taskIndex == -1) return;
      
      final originalTask = state.tasks[taskIndex];
      if (!originalTask.isCompleted) return; // Already incomplete
      
      Task? updatedTask;
      
      // Use Google Tasks service if signed in and can sync
      if (_authService.isSignedIn && _tasksService.canSync) {
        updatedTask = await _tasksService.uncompleteTask(originalTask);
      }
      
      // Fallback to local update
      updatedTask ??= originalTask.copyWith(
        isCompleted: false,
        completedAt: null,
        lastModified: DateTime.now(),
        needsSync: _authService.isSignedIn,
      );
      
      final newTasks = [...state.tasks];
      newTasks[taskIndex] = updatedTask;
      
      state = state.copyWith(tasks: newTasks);
      await TaskStorage.saveTasks(newTasks);
      
      // Auto-sync if signed in and task wasn't already synced
      if (_authService.isSignedIn && !state.isSyncing && updatedTask.needsSync) {
        syncWithGoogle();
      }
    } catch (e) {
      debugPrint('Error uncompleting task: $e');
    }
  }

  /// Remove a task
  Future<void> removeTask(String taskId) async {
    try {
      final taskToRemove = state.tasks.firstWhere(
        (task) => task.id == taskId,
        orElse: () => Task(id: '', title: ''),
      );
      
      if (taskToRemove.id.isEmpty) return;
      
      // If task has Google ID and we're signed in, mark for deletion sync
      if (taskToRemove.googleTaskId != null && _authService.isSignedIn) {
        final deletedTask = taskToRemove.copyWith(
          isDeleted: true,
          lastModified: DateTime.now(),
          needsSync: true,
        );
        
        final newTasks = state.tasks.map((task) => 
          task.id == taskId ? deletedTask : task
        ).toList();
        
        // Remove any duplicates that might exist
        final deduplicatedTasks = _syncService.removeDuplicates(newTasks);
        
        state = state.copyWith(tasks: deduplicatedTasks);
        await TaskStorage.saveTasks(deduplicatedTasks);
        
        // Auto-sync to delete from Google
        if (!state.isSyncing) {
          syncWithGoogle();
        }
      } else {
        // Remove locally only
        final newTasks = state.tasks.where((task) => task.id != taskId).toList();
        
        // Remove any duplicates that might exist
        final deduplicatedTasks = _syncService.removeDuplicates(newTasks);
        
        state = state.copyWith(tasks: deduplicatedTasks);
        await TaskStorage.saveTasks(deduplicatedTasks);
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

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    return await TaskStorage.getSyncStats();
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    return await TaskStorage.getLastSyncTime();
  }

  /// Get tasks that need syncing
  Future<List<Task>> getTasksNeedingSync() async {
    return await TaskStorage.getTasksNeedingSync();
  }

  /// Force sync all tasks
  Future<void> forceSyncAll() async {
    if (!state.isSignedIn) {
      state = state.copyWith(syncStatus: 'Not signed in');
      return;
    }

    state = state.copyWith(isSyncing: true, syncStatus: 'Force syncing...');
    
    try {
      // Mark all tasks as needing sync
      final tasks = state.tasks;
      final updatedTasks = tasks.map((task) => task.copyWith(
        needsSync: true,
        lastModified: DateTime.now(),
      )).toList();
      
      await TaskStorage.saveTasks(updatedTasks);
      state = state.copyWith(tasks: updatedTasks);
      
      // Perform sync
      await syncWithGoogle();
    } catch (e) {
      debugPrint('Error force syncing: $e');
      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Force sync failed: ${e.toString()}',
      );
    }
  }

  /// Clean up deleted tasks
  Future<void> cleanupDeletedTasks() async {
    try {
      await TaskStorage.cleanupDeletedTasks();
      await _loadTasks();
      state = state.copyWith(syncStatus: 'Deleted tasks cleaned up');
    } catch (e) {
      debugPrint('Error cleaning up deleted tasks: $e');
      state = state.copyWith(syncStatus: 'Cleanup failed');
    }
  }

  /// Reset sync status for a specific task
  Future<void> resetTaskSync(String taskId) async {
    try {
      final tasks = state.tasks;
      final taskIndex = tasks.indexWhere((task) => task.id == taskId);
      
      if (taskIndex != -1) {
        final updatedTask = tasks[taskIndex].copyWith(
          needsSync: true,
          lastModified: DateTime.now(),
        );
        
        final updatedTasks = [...tasks];
        updatedTasks[taskIndex] = updatedTask;
        
        await TaskStorage.saveTasks(updatedTasks);
        state = state.copyWith(tasks: updatedTasks);
        
        // Trigger auto-sync if enabled
        if (state.isSignedIn) {
          await syncWithGoogle();
        }
      }
    } catch (e) {
      debugPrint('Error resetting task sync: $e');
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

// Provider for sync statistics
final syncStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final taskNotifier = ref.read(taskProvider.notifier);
  return await taskNotifier.getSyncStats();
});

// Provider for last sync time
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final taskNotifier = ref.read(taskProvider.notifier);
  return await taskNotifier.getLastSyncTime();
});

// Provider for tasks needing sync
final tasksNeedingSyncProvider = FutureProvider<List<Task>>((ref) async {
  final taskNotifier = ref.read(taskProvider.notifier);
  return await taskNotifier.getTasksNeedingSync();
});