import 'package:to_do_app/common_imports.dart';


class TodoListData {
  String title;
  List<ScheduleTask> todos;
  String category; // e.g., 'Work', 'Personal', 'Shopping'
  Color categoryColor;
  TodoListData({
    required this.category,
    required this.categoryColor,
    required this.title,
    required this.todos,
  });

  factory TodoListData.fromJson(Map<String, dynamic> json) {
    return TodoListData(
      title: json['title'],
      todos: (json['todos'] as List)
          .map((todo) => ScheduleTask.fromJson(todo))
          .toList(),
      category: json['category'] ?? 'Uncategorized', // Default value
      categoryColor:
          Color(json['categoryColor'] ?? 0xFFFF80AB), // Default pink color
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'category': category,
      'categoryColor': categoryColor.value,
    };
  }
}
