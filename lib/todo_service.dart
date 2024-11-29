import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TodoItem {
  String text;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;
  bool isDetailsExpanded;

  TodoItem({
    required this.text,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.isDetailsExpanded = false,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      text: json['text'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      isDetailsExpanded: json['isDetailsExpanded'] ?? false, // Default value
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isDetailsExpanded': isDetailsExpanded,
    };
  }
}

// Model class for TodoListData
class TodoListData {
  String title;
  List<TodoItem> todos;

  TodoListData({
    required this.title,
    required this.todos,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'todos': todos.map((todo) => todo.toJson()).toList(),
    };
  }

  factory TodoListData.fromJson(Map<String, dynamic> json) {
    return TodoListData(
      title: json['title'],
      todos: (json['todos'] as List)
          .map((todo) => TodoItem.fromJson(todo))
          .toList(),
    );
  }
}

// Storage service class
class TodoStorage {
  static const String _storageKey = 'todo_lists';

  // Load all todo lists
  static Future<List<TodoListData>> loadTodoLists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => TodoListData.fromJson(json)).toList();
  }

  // Save all todo lists
  static Future<void> saveTodoLists(List<TodoListData> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(lists.map((list) => list.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  // Add a new todo list
  static Future<void> addTodoList(TodoListData todoList) async {
    final lists = await loadTodoLists();
    lists.add(todoList);
    await saveTodoLists(lists);
  }

  // Update an existing todo list
  static Future<void> updateTodoList(TodoListData updatedList) async {
    final lists = await loadTodoLists();
    final index = lists.indexWhere((list) => list.title == updatedList.title);
    if (index != -1) {
      lists[index] = updatedList;
      await saveTodoLists(lists);
    }
  }

  // Delete a todo list
  static Future<void> deleteTodoList(String title) async {
    final lists = await loadTodoLists();
    lists.removeWhere((list) => list.title == title);
    await saveTodoLists(lists);
  }
}
