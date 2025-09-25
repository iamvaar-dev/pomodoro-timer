import '../services/unique_id_service.dart';

class Task {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? notes;
  final String? googleTaskId;
  final DateTime? lastSynced;
  final DateTime? lastModified;
  final bool isDeleted;
  final bool needsSync;

  Task({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.dueDate,
    this.completedAt,
    this.notes,
    this.googleTaskId,
    this.lastSynced,
    this.lastModified,
    this.isDeleted = false,
    this.needsSync = true,
  }) : 
    this.id = id ?? UniqueIdService.generateTaskId(),
    this.createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? completedAt,
    String? notes,
    String? googleTaskId,
    DateTime? lastSynced,
    DateTime? lastModified,
    bool? isDeleted,
    bool? needsSync,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      googleTaskId: googleTaskId ?? this.googleTaskId,
      lastSynced: lastSynced ?? this.lastSynced,
      lastModified: lastModified ?? this.lastModified,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'notes': notes,
    'googleTaskId': googleTaskId,
    'lastSynced': lastSynced?.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
    'isDeleted': isDeleted,
    'needsSync': needsSync,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    isCompleted: json['isCompleted'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    notes: json['notes'],
    googleTaskId: json['googleTaskId'],
    lastSynced: json['lastSynced'] != null ? DateTime.parse(json['lastSynced']) : null,
    lastModified: json['lastModified'] != null ? DateTime.parse(json['lastModified']) : null,
    isDeleted: json['isDeleted'] ?? false,
    needsSync: json['needsSync'] ?? true,
  );

  /// Generate a content hash for this task (for deduplication)
  String get contentHash => UniqueIdService.generateContentHash(title, notes, dueDate, isCompleted);

  /// Check if this task has the same content as another task
  bool hasSameContentAs(Task other) {
    return UniqueIdService.hasSameContent(
      title, notes, dueDate, isCompleted,
      other.title, other.notes, other.dueDate, other.isCompleted,
    );
  }

  /// Check if this task is a duplicate of another task
  bool isDuplicateOf(Task other) {
    return id != other.id && hasSameContentAs(other);
  }
}