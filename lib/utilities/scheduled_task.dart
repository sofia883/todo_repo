import 'package:to_do_app/common_imports.dart';

class ScheduleTask {
  final String id;
  final String userId; 

  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime dueDate;
  final TimeOfDay? dueTime;

  bool isSubtasksExpanded = false;
  bool isOverdue = false;
  final bool isQuickTask; 
  bool isCompleted;

  DateTime? completedAt;
  List<ScheduleSubTask> subtasks; 

  ScheduleTask({
    required this.id,
    required this.userId, 
    required this.title,
    required this.description,
    required this.createdAt,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.isQuickTask = false, 
    this.completedAt,
    this.subtasks = const [], 
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'dueTime': dueTime != null
          ? {'hour': dueTime!.hour, 'minute': dueTime!.minute}
          : null,
      'isCompleted': isCompleted,
      'isQuickTask': isQuickTask,
      'completedAt': completedAt?.toIso8601String(),
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
    };
  }

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    return ScheduleTask(
      id: json['id'],
      userId: json['userId'] ?? '', // Parse userId or use an empty string
      title: json['title'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: DateTime.parse(json['dueDate']),
      dueTime: json['dueTime'] != null
          ? TimeOfDay(
              hour: json['dueTime']['hour'],
              minute: json['dueTime']['minute'],
            )
          : null,
      isCompleted: json['isCompleted'] ?? false,
      isQuickTask: json['isQuickTask'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      subtasks: (json['subtasks'] as List?)
              ?.map((subtask) => ScheduleSubTask.fromJson(subtask))
              .toList() ??
          [],
    );
  }

  ScheduleTask copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? isCompleted,
    bool? isQuickTask,
    DateTime? completedAt,
    List<ScheduleSubTask>? subtasks,
  }) {
    return ScheduleTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      isCompleted: isCompleted ?? this.isCompleted,
      isQuickTask: isQuickTask ?? this.isQuickTask,
      completedAt: completedAt ?? this.completedAt,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  /// Check if the task is overdue
  bool get checkOverdue {
    final now = DateTime.now();
    return dueDate.isBefore(now) && !isCompleted;
  }
}

class ScheduleSubTask {
  final String id;
  final String title;
  bool isCompleted;
  DateTime? completedAt;

  ScheduleSubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ScheduleSubTask.fromJson(Map<String, dynamic> json) {
    return ScheduleSubTask(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}