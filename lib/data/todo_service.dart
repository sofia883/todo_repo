import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}class TodoItem {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime dueDate;
  final TimeOfDay? dueTime;
   bool isSubtasksExpanded = false;
  bool isCompleted;
  DateTime? completedAt;
  List<SubTask> subtasks; // Add this field

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.completedAt,
    this.subtasks = const [], // Initialize empty subtasks list
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'dueTime': dueTime != null
          ? {'hour': dueTime!.hour, 'minute': dueTime!.minute}
          : null,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'],
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
      isCompleted: json['isCompleted'],
      completedAt:
          json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      subtasks: (json['subtasks'] as List?)
              ?.map((subtask) => SubTask.fromJson(subtask))
              .toList() ??
          [],
    );
  }
  bool get isOverdue {
    final now = DateTime.now();
    if (isCompleted) return false;

    if (dueTime != null) {
      final dueDateTime = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueTime!.hour,
        dueTime!.minute,
      );
      return dueDateTime.isBefore(now);
    }

    return dueDate.isBefore(DateTime(now.year, now.month, now.day));
  }
}

class TodoStorage {
  static const String _todosKey = 'todos';
  final _todoStreamController = StreamController<List<TodoItem>>.broadcast();

  static const String _deletedTodosKey = 'deleted_todos';

  // Existing methods...

  // Delete todo with backup
  Future<void> deleteTodo(String todoId) async {
    final todos = await _loadTodos();
    final deletedTodo = todos.firstWhere((todo) => todo.id == todoId);

    // Store the deleted todo
    final prefs = await SharedPreferences.getInstance();
    final deletedTodos = await _loadDeletedTodos();
    deletedTodos[todoId] = {
      'todo': deletedTodo.toJson(),
      'deletedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_deletedTodosKey, jsonEncode(deletedTodos));

    // Remove from active todos
    todos.removeWhere((todo) => todo.id == todoId);
    await _saveTodos(todos);
  }

  // Restore deleted todo
  Future<void> restoreTodo(TodoItem todo) async {
    try {
      // Load current todos
      final todos = await _loadTodos();

      // Add the todo back to the list
      todos.add(todo);

      // Save the updated list
      await _saveTodos(todos);

      // Remove from deleted todos backup
      final prefs = await SharedPreferences.getInstance();
      final deletedTodos = await _loadDeletedTodos();
      deletedTodos.remove(todo.id);
      await prefs.setString(_deletedTodosKey, jsonEncode(deletedTodos));
    } catch (e) {
      print('Error restoring todo: $e');
      throw Exception('Failed to restore todo: ${e.toString()}');
    }
  }

  // Load deleted todos from SharedPreferences
  Future<Map<String, dynamic>> _loadDeletedTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? deletedTodosJson = prefs.getString(_deletedTodosKey);

    if (deletedTodosJson != null) {
      return jsonDecode(deletedTodosJson);
    }
    return {};
  }

  // Clean up old deleted todos
  Future<void> cleanupDeletedTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedTodos = await _loadDeletedTodos();
      final now = DateTime.now();

      // Remove todos older than 24 hours
      deletedTodos.removeWhere((todoId, data) {
        final deletedAt = DateTime.parse(data['deletedAt']);
        return now.difference(deletedAt).inHours > 24;
      });

      await prefs.setString(_deletedTodosKey, jsonEncode(deletedTodos));
    } catch (e) {
      print('Error cleaning up deleted todos: $e');
    }
  }

  // Get all deleted todos that can still be restored
  Future<List<TodoItem>> getDeletedTodos() async {
    final deletedTodos = await _loadDeletedTodos();
    final now = DateTime.now();

    return deletedTodos.entries
        .where((entry) {
          final deletedAt = DateTime.parse(entry.value['deletedAt']);
          return now.difference(deletedAt).inHours <= 24;
        })
        .map((entry) => TodoItem.fromJson(entry.value['todo']))
        .toList();
  }

  // Clean up resources
  void dispose() {
    _todoStreamController.close();
  }

  // Get todos stream
  Stream<List<TodoItem>> getTodosStream() {
    _loadTodos(); // Load initial data
    return _todoStreamController.stream;
  }

  // Load todos from SharedPreferences
  Future<List<TodoItem>> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString(_todosKey);

    if (todosJson != null) {
      final List<dynamic> decoded = jsonDecode(todosJson);
      final todos = decoded.map((item) => TodoItem.fromJson(item)).toList();
      _todoStreamController.add(todos);
      return todos;
    }

    _todoStreamController.add([]);
    return [];
  }

  // Save todos to SharedPreferences
  Future<void> _saveTodos(List<TodoItem> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedTodos =
        jsonEncode(todos.map((todo) => todo.toJson()).toList());
    await prefs.setString(_todosKey, encodedTodos);
    _todoStreamController.add(todos);
  }

  // Add new todo
  Future<void> addTodo(TodoItem todo) async {
    final todos = await _loadTodos();
    todos.add(todo);
    await _saveTodos(todos);
  }

  // Update todo status
  Future<void> updateTodoStatus(String todoId, bool isCompleted) async {
    final todos = await _loadTodos();
    final index = todos.indexWhere((todo) => todo.id == todoId);
    if (index != -1) {
      todos[index].isCompleted = isCompleted;
      todos[index].completedAt = isCompleted ? DateTime.now() : null;
      await _saveTodos(todos);
    }
  }
  Future<void> updateTodo(TodoItem todo) async {
    final todos = await _loadTodos();
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      todos[index] = todo;
      await _saveTodos(todos);
    } else {
      throw Exception('Todo not found');
    }
  }

  Future<void> updateTodoDate(
      String todoId, DateTime newDate, TimeOfDay? newTime) async {
    final todos = await _loadTodos();
    final index = todos.indexWhere((todo) => todo.id == todoId);
    if (index != -1) {
      final updatedTodo = TodoItem(
        id: todos[index].id,
        title: todos[index].title,
        description: todos[index].description,
        createdAt: todos[index].createdAt,
        dueDate: newDate,
        dueTime: newTime, // Update with the new time
        isCompleted: todos[index].isCompleted,
        completedAt: todos[index].completedAt,
      );
      todos[index] = updatedTodo;
      await _saveTodos(todos);
    }
  }
}

// Simple user preferences storage
class UserPreferences {
  static const String _userKey = 'user_preferences';

  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(preferences));
  }

  Future<Map<String, dynamic>> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final String? prefsJson = prefs.getString(_userKey);
    if (prefsJson != null) {
      return jsonDecode(prefsJson);
    }
    return {};
  }
  
}

class SubTask {
  final String id;
  final String title;
  bool isCompleted;
  DateTime? completedAt;

  SubTask({
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

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'],
      completedAt:
          json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }
}
