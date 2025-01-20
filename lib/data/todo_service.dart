import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

// Rename to QuickSubTask for consistency
class QuickSubTask {
  final String id;
  final String title;
  bool isCompleted;

  QuickSubTask({
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

  factory QuickSubTask.fromJson(Map<String, dynamic> json) {
    return QuickSubTask(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  QuickSubTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return QuickSubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class QuickTask {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<QuickSubTask> subtasks; // Updated to QuickSubTask
  bool? isCompleted;

  QuickTask({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.subtasks,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
      'isCompleted': isCompleted,
    };
  }

  factory QuickTask.fromJson(Map<String, dynamic> json) {
    return QuickTask(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      subtasks: (json['subtasks'] as List)
          .map((subtask) => QuickSubTask.fromJson(subtask))
          .toList(),
      isCompleted: json['isCompleted'],
    );
  }

  QuickTask copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<QuickSubTask>? subtasks,
    bool? isCompleted,
  }) {
    return QuickTask(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      subtasks: subtasks ?? this.subtasks,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class QuickTaskService {
  static const String _storageKey = 'quick_tasks';

  static final QuickTaskService _instance = QuickTaskService._internal();
  factory QuickTaskService() => _instance;
  QuickTaskService._internal();

  static final _taskController = StreamController<List<QuickTask>>.broadcast();
  Stream<List<QuickTask>> get tasksStream => _taskController.stream;

  static Future<List<QuickTask>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksString = prefs.getString(_storageKey);
    if (tasksString == null) return [];

    final tasksList = jsonDecode(tasksString) as List;
    return tasksList.map((json) => QuickTask.fromJson(json)).toList();
  }

  static Future<void> _saveTasks(List<QuickTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(tasksJson));
    _taskController.add(tasks);
  }

  static Future<void> updateTaskCompletion(
      String taskId, bool isCompleted) async {
    final tasks = await loadTasks();
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex != -1) {
      tasks[taskIndex] = tasks[taskIndex].copyWith(
        isCompleted: isCompleted,
        subtasks: tasks[taskIndex]
            .subtasks
            .map((subtask) => subtask.copyWith(isCompleted: isCompleted))
            .toList(),
      );

      await _saveTasks(tasks);
    }
  }

  static Future<void> updateSubtaskCompletion(
      String taskId, String subtaskId, bool isCompleted) async {
    final tasks = await loadTasks();
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      final updatedSubtasks = task.subtasks
          .map((subtask) => subtask.id == subtaskId
              ? subtask.copyWith(isCompleted: isCompleted)
              : subtask)
          .toList();

      final allSubtasksCompleted =
          updatedSubtasks.every((subtask) => subtask.isCompleted);

      tasks[taskIndex] = task.copyWith(
        subtasks: updatedSubtasks,
        isCompleted: allSubtasksCompleted,
      );

      await _saveTasks(tasks);
    }
  }

  static Future<void> addTask(QuickTask task) async {
    final tasks = await loadTasks();
    tasks.add(task);
    await _saveTasks(tasks);
  }

  static Future<void> deleteTask(String taskId) async {
    final tasks = await loadTasks();
    tasks.removeWhere((task) => task.id == taskId);
    await _saveTasks(tasks);
  }

  static Future<void> updateTask(QuickTask updatedTask) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((task) => task.id == updatedTask.id);

    if (index != -1) {
      tasks[index] = updatedTask;
      await _saveTasks(tasks);
    }
  }

  void dispose() {
    _taskController.close();
  }
}
class QuickTaskItem extends StatefulWidget {
  final QuickTask task;
  final VoidCallback onUpdate;

  const QuickTaskItem({
    Key? key,
    required this.task,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<QuickTaskItem> createState() => _QuickTaskItemState();
}

class _QuickTaskItemState extends State<QuickTaskItem> {
  bool isExpanded = false;

  Future<void> _handleMainTaskCompletion(bool? value) async {
    if (value == null) return;

    try {
      // Update main task and all subtasks
      await QuickTaskService.updateTaskCompletion(widget.task.id, value);
      widget.onUpdate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update task')),
      );
    }
  }

  Future<void> _handleSubtaskCompletion(String subtaskId, bool value) async {
    try {
      // Update subtask and check main task completion
      await QuickTaskService.updateSubtaskCompletion(
        widget.task.id,
        subtaskId,
        value,
      );
      widget.onUpdate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update subtask')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSubtasks = widget.task.subtasks.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Main task checkbox
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: widget.task.isCompleted ?? false,
                    onChanged: _handleMainTaskCompletion,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Task title
                Expanded(
                  child: Text(
                    widget.task.title,
                    style: TextStyle(
                      fontSize: 16,
                      decoration: widget.task.isCompleted ?? false
                          ? TextDecoration.lineThrough
                          : null,
                      color: widget.task.isCompleted ?? false
                          ? Theme.of(context).disabledColor
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                
                // Show dropdown only if has subtasks
                if (hasSubtasks)
                  IconButton(
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                    onPressed: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  ),
              ],
            ),
            
            // Subtasks section
            if (hasSubtasks && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 8),
                child: Column(
                  children: widget.task.subtasks.map((subtask) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: subtask.isCompleted,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  _handleSubtaskCompletion(subtask.id, value);
                                }
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subtask.title,
                              style: TextStyle(
                                fontSize: 14,
                                decoration: subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: subtask.isCompleted
                                    ? Theme.of(context).disabledColor
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}