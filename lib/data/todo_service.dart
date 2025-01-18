import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/data/todo_notification_service.dart';

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
}

class TodoItem {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime dueDate;
  final TimeOfDay? dueTime;
  bool isSubtasksExpanded = false;
  bool isOverdue = false;
  final bool isQuickTask; // New field
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
    this.isQuickTask = false, // Default to false

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
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      subtasks: (json['subtasks'] as List?)
              ?.map((subtask) => SubTask.fromJson(subtask))
              .toList() ??
          [],
    );
  }
}

class TodoStorage {
  static const String _todosKey = 'todos';
  final _todoStreamController = StreamController<List<TodoItem>>.broadcast();
  final NotificationService _notificationService = NotificationService();

  static const String _deletedTodosKey = 'deleted_todos';

  // Existing methods...
  Future<void> checkOverdueTasks() async {
    final todos = await _loadTodos();
    final now = DateTime.now();

    for (final todo in todos) {
      if (!todo.isCompleted) {
        DateTime dueDateTime;
        if (todo.dueTime != null) {
          dueDateTime = DateTime(
            todo.dueDate.year,
            todo.dueDate.month,
            todo.dueDate.day,
            todo.dueTime!.hour,
            todo.dueTime!.minute,
          );
        } else {
          dueDateTime = DateTime(
            todo.dueDate.year,
            todo.dueDate.month,
            todo.dueDate.day,
            23, // End of day
            59,
          );
        }

        if (dueDateTime.isBefore(now) && !todo.isOverdue) {
          todo.isOverdue = true;
        }
      }
    }

    await _saveTodos(todos);
  }

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
    await _notificationService.cancelTodoNotifications(todoId);
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

  Future<void> addTodo(TodoItem todo) async {
    final todos = await _loadTodos();
    todos.add(todo);
    await _saveTodos(todos);

    // Schedule notification
  }

  Future<void> updateTodo(TodoItem todo) async {
    final todos = await _loadTodos();
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      todos[index] = todo;
      await _saveTodos(todos);

      // Update notification
    }
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

  // Future<void> updateTodo(TodoItem todo) async {
  //   final todos = await _loadTodos();
  //   final index = todos.indexWhere((t) => t.id == todo.id);
  //   if (index != -1) {
  //     todos[index] = todo;
  //     await _saveTodos(todos);
  //   } else {
  //     throw Exception('Todo not found');
  //   }
  //   await _notificationService.scheduleTodoNotification(todo);
  // }

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

class QuickTask {
  String id;
  String title;
  List<SubTask> subtasks;
  DateTime createdAt;
  DateTime? completedAt;
  bool isCompleted;

  QuickTask({
    required this.id,
    required this.title,
    required this.subtasks,
    required this.createdAt,
    this.completedAt,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtasks': subtasks.map((st) => st.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'isCompleted': isCompleted,
      };

  factory QuickTask.fromJson(Map<String, dynamic> json) => QuickTask(
        id: json['id'],
        title: json['title'],
        subtasks: (json['subtasks'] as List)
            .map((st) => SubTask.fromJson(st))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'])
            : null,
        isCompleted: json['isCompleted'],
      );
}

class QuickSubTask {
  String id;
  String title;
  bool isCompleted;

  QuickSubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory QuickSubTask.fromJson(Map<String, dynamic> json) => QuickSubTask(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'],
      );
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
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}

class QuickTaskStorage {
  static const String _quickTasksKey = 'quick_tasks';
  final _quickTaskStreamController =
      StreamController<List<QuickTask>>.broadcast();

  // Get stream of quick tasks
  Stream<List<QuickTask>> getQuickTasksStream() {
    _loadQuickTasks(); // Load initial data
    return _quickTaskStreamController.stream;
  }

  // Load quick tasks from SharedPreferences
  Future<List<QuickTask>> _loadQuickTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_quickTasksKey);

    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      final tasks = decoded.map((item) => QuickTask.fromJson(item)).toList();
      _quickTaskStreamController.add(tasks);
      return tasks;
    }

    _quickTaskStreamController.add([]);
    return [];
  }

  // Save quick tasks to SharedPreferences
  Future<void> _saveQuickTasks(List<QuickTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedTasks =
        jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_quickTasksKey, encodedTasks);
    _quickTaskStreamController.add(tasks);
  }

  // Add a new quick task
  Future<void> addQuickTask(QuickTask task) async {
    final tasks = await _loadQuickTasks();
    tasks.add(task);
    await _saveQuickTasks(tasks);
  }

  // Update an existing quick task
  Future<void> updateQuickTask(QuickTask task) async {
    final tasks = await _loadQuickTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;
      await _saveQuickTasks(tasks);
    } else {
      throw Exception('Quick task not found');
    }
  }

  // Delete a quick task
  Future<void> deleteQuickTask(String taskId) async {
    final tasks = await _loadQuickTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await _saveQuickTasks(tasks);
  }

  // Update quick task completion status
  Future<void> updateQuickTaskStatus(String taskId, bool isCompleted) async {
    final tasks = await _loadQuickTasks();
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      tasks[index].isCompleted = isCompleted;
      tasks[index].completedAt = isCompleted ? DateTime.now() : null;
      await _saveQuickTasks(tasks);
    }
  }

  // Update subtask completion status
  Future<void> updateSubtaskStatus(
      String taskId, String subtaskId, bool isCompleted) async {
    final tasks = await _loadQuickTasks();
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      final subtaskIndex = tasks[taskIndex]
          .subtasks
          .indexWhere((subtask) => subtask.id == subtaskId);
      if (subtaskIndex != -1) {
        tasks[taskIndex].subtasks[subtaskIndex].isCompleted = isCompleted;
        await _saveQuickTasks(tasks);
      }
    }
  }

  // Get all completed quick tasks
  Future<List<QuickTask>> getCompletedQuickTasks() async {
    final tasks = await _loadQuickTasks();
    return tasks.where((task) => task.isCompleted).toList();
  }

  // Get all incomplete quick tasks
  Future<List<QuickTask>> getIncompleteQuickTasks() async {
    final tasks = await _loadQuickTasks();
    return tasks.where((task) => !task.isCompleted).toList();
  }

  // Clean up resources
  void dispose() {
    _quickTaskStreamController.close();
  }
}
