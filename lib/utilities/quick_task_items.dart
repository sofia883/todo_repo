class DailyTask {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final List<DailySubTask> subtasks;
  bool? isCompleted;

  DailyTask({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.subtasks,
    this.isCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
      'isCompleted': isCompleted,
    };
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'],
      userId: json['userId'] ?? '',
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      subtasks: (json['subtasks'] as List)
          .map((subtask) => DailySubTask.fromJson(subtask))
          .toList(),
      isCompleted: json['isCompleted'],
    );
  }

  DailyTask copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? createdAt,
    List<DailySubTask>? subtasks,
    bool? isCompleted,
  }) {
    return DailyTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      subtasks: subtasks ?? this.subtasks,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class DailySubTask {
  final String id;
  final String title;
  bool isCompleted;

  DailySubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory DailySubTask.fromJson(Map<String, dynamic> json) {
    return DailySubTask(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  DailySubTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return DailySubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
