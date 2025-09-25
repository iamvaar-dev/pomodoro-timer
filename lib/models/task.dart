import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final String? googleTaskId;
  final DateTime? lastSynced;

  Task({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.googleTaskId,
    this.lastSynced,
  }) : 
    this.id = id ?? const Uuid().v4(),
    this.createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    String? googleTaskId,
    DateTime? lastSynced,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      googleTaskId: googleTaskId ?? this.googleTaskId,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'googleTaskId': googleTaskId,
    'lastSynced': lastSynced?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    isCompleted: json['isCompleted'],
    createdAt: DateTime.parse(json['createdAt']),
    googleTaskId: json['googleTaskId'],
    lastSynced: json['lastSynced'] != null ? DateTime.parse(json['lastSynced']) : null,
  );
}