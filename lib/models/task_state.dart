import 'task.dart';

class TaskState {
  final List<Task> tasks;
  final bool isSignedIn;
  final String? userEmail;
  final bool isSyncing;
  final String syncStatus;

  const TaskState({
    required this.tasks,
    required this.isSignedIn,
    this.userEmail,
    required this.isSyncing,
    required this.syncStatus,
  });

  TaskState copyWith({
    List<Task>? tasks,
    bool? isSignedIn,
    String? userEmail,
    bool? isSyncing,
    String? syncStatus,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      userEmail: userEmail ?? this.userEmail,
      isSyncing: isSyncing ?? this.isSyncing,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskState &&
        other.tasks == tasks &&
        other.isSignedIn == isSignedIn &&
        other.userEmail == userEmail &&
        other.isSyncing == isSyncing &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode {
    return tasks.hashCode ^
        isSignedIn.hashCode ^
        userEmail.hashCode ^
        isSyncing.hashCode ^
        syncStatus.hashCode;
  }
}