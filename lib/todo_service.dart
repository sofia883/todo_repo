import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class TodoItem {
  String title; // Title of the todo item
  String description; // Description of the todo item
  DateTime createdAt; // When the item was created
  DateTime? completedAt; // When the item was completed
  DateTime dueDate; // Due date for the item
  TimeOfDay? dueTime; // Due time for the item
  bool isCompleted; // Completion status
  bool? isDetailsExpanded; // Whether details are expanded
  Color? backgroundColor; // Persistent background color for UI

  TodoItem({
    required this.title,
    this.description = '',
    required this.createdAt,
    this.completedAt,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.isDetailsExpanded = false,
    this.backgroundColor,
  });

  /// Factory method to create a `TodoItem` instance from JSON.
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      title: json['title'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      dueDate: DateTime.parse(json['dueDate']),
      dueTime: json['dueTime'] != null
          ? TimeOfDay(
              hour: json['dueTime']['hour'],
              minute: json['dueTime']['minute'],
            )
          : null,
      isCompleted: json['isCompleted'] ?? false,
      isDetailsExpanded: json['isDetailsExpanded'] ?? false,
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'])
          : null,
    );
  }

  /// Converts the `TodoItem` instance to JSON format.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'dueTime': dueTime != null
          ? {'hour': dueTime!.hour, 'minute': dueTime!.minute}
          : null,
      'isCompleted': isCompleted,
      'isDetailsExpanded': isDetailsExpanded,
      'backgroundColor': backgroundColor?.value,
    };
  }
}

// Model class for TodoListData
class TodoListData {
  String title;
  List<TodoItem> todos;
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
        .map((todo) => TodoItem.fromJson(todo))
        .toList(),
    category: json['category'] ?? 'Uncategorized', // Default value
    categoryColor: Color(json['categoryColor'] ?? 0xFFFF80AB), // Default pink color
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
