import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/data/todo_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Stream<User?> get authStateChanges => _auth.authStateChanges();

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
  final List<QuickSubTask> subtasks;
  bool? isCompleted;

  QuickTask({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.subtasks,
    this.isCompleted,
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
      await FirebaseTaskService.updateQuickTaskCompletion(
          widget.task.id, value);
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
      await FirebaseTaskService.updateQuickSubtaskCompletion(
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
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
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

class FirebaseTaskService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static bool _isOnline = true;
 static Future<bool> isNetworkAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
  // Initialize offline persistence
  static Future<void> initializeOfflineStorage() async {
    await _firestore.enablePersistence();
    await LocalStorageService.init();

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
          _isOnline = result != ConnectivityResult.none;
        } as void Function(List<ConnectivityResult> event)?);
  }

  // Modified addScheduledTask with offline support
  static Future<void> addScheduledTask(TodoItem task) async {
    try {
      if (_isOnline) {
        await _scheduledTasksRef.doc(task.id).set(task.toJson());
      }

      // Save to local storage regardless of online status
      final localTasks = LocalStorageService.getScheduledTasks();
      localTasks.add(task);
      await LocalStorageService.saveScheduledTasks(localTasks);
    } catch (e) {
      // If Firebase operation fails, ensure local storage is updated
      final localTasks = LocalStorageService.getScheduledTasks();
      localTasks.add(task);
      await LocalStorageService.saveScheduledTasks(localTasks);
    }
  }

  // Modified getScheduledTasksStream with offline support
  static Stream<List<TodoItem>> getScheduledTasksStream() {
    if (_isOnline) {
      return _scheduledTasksRef.snapshots().map((snapshot) {
        final tasks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return TodoItem.fromJson(data);
        }).toList();

        // Update local storage when online data is received
        LocalStorageService.saveScheduledTasks(tasks);
        return tasks;
      });
    } else {
      // Return stream from local storage when offline
      return Stream.value(LocalStorageService.getScheduledTasks());
    }
  }

  // Similar modifications for QuickTasks
  static Future<void> addQuickTask(QuickTask task) async {
    try {
      if (_isOnline) {
        await _quickTasksRef.doc(task.id).set(task.toJson());
      }

      final localTasks = LocalStorageService.getQuickTasks();
      localTasks.add(task);
      await LocalStorageService.saveQuickTasks(localTasks);
    } catch (e) {
      final localTasks = LocalStorageService.getQuickTasks();
      localTasks.add(task);
      await LocalStorageService.saveQuickTasks(localTasks);
    }
  }

  static Stream<List<QuickTask>> getQuickTasksStream() {
    if (_isOnline) {
      return _quickTasksRef.snapshots().map((snapshot) {
        final tasks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return QuickTask.fromJson(data);
        }).toList();

        LocalStorageService.saveQuickTasks(tasks);
        return tasks;
      });
    } else {
      return Stream.value(LocalStorageService.getQuickTasks());
    }
  }

  // Add sync method to synchronize local and remote data
  static Future<void> syncWithServer() async {
    if (!_isOnline) return;

    try {
      // Sync scheduled tasks
      final localScheduledTasks = LocalStorageService.getScheduledTasks();
      for (var task in localScheduledTasks) {
        await _scheduledTasksRef.doc(task.id).set(task.toJson());
      }

      // Sync quick tasks
      final localQuickTasks = LocalStorageService.getQuickTasks();
      for (var task in localQuickTasks) {
        await _quickTasksRef.doc(task.id).set(task.toJson());
      }
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  // Get current user ID
  static String get _userId => _auth.currentUser?.uid ?? '';

  // Reference to user's scheduled tasks collection
  static CollectionReference get _scheduledTasksRef =>
      _firestore.collection('users').doc(_userId).collection('scheduled_tasks');

  // Reference to user's quick tasks collection
  static CollectionReference get _quickTasksRef =>
      _firestore.collection('users').doc(_userId).collection('quick_tasks');

  static Future<void> updateScheduledTask(TodoItem task) async {
    await _scheduledTasksRef.doc(task.id).update(task.toJson());
  }

  static Future<void> deleteScheduledTask(String taskId) async {
    await _scheduledTasksRef.doc(taskId).delete();
  }

  static Future<void> updateScheduledTaskStatus(
      String taskId, bool isCompleted) async {
    await _scheduledTasksRef.doc(taskId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  static Future<void> updateQuickTask(QuickTask task) async {
    await _quickTasksRef.doc(task.id).update(task.toJson());
  }

  static Future<void> deleteQuickTask(String taskId) async {
    await _quickTasksRef.doc(taskId).delete();
  }

  static Future<void> updateQuickTaskCompletion(
    String taskId,
    bool isCompleted,
  ) async {
    await _quickTasksRef.doc(taskId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    });
  }

  static Future<void> updateQuickSubtaskCompletion(
    String taskId,
    String subtaskId,
    bool isCompleted,
  ) async {
    final taskDoc = await _quickTasksRef.doc(taskId).get();
    final taskData = taskDoc.data() as Map<String, dynamic>;
    final subtasks = List<Map<String, dynamic>>.from(taskData['subtasks']);

    final subtaskIndex = subtasks.indexWhere((s) => s['id'] == subtaskId);
    if (subtaskIndex != -1) {
      subtasks[subtaskIndex]['isCompleted'] = isCompleted;

      // Check if all subtasks are completed
      final allCompleted = subtasks.every((s) => s['isCompleted'] == true);

      await _quickTasksRef.doc(taskId).update({
        'subtasks': subtasks,
        'isCompleted': allCompleted,
      });
    }
  }

  static Future<void> updateRescheduleScheduledTask(
      String taskId, DateTime newDate, TimeOfDay? newTime) async {
    try {
      // Create a map of fields to update
      Map<String, dynamic> updateData = {
        'dueDate': newDate.toIso8601String(),
      };

      // Only include dueTime if it's provided
      if (newTime != null) {
        updateData['dueTime'] = {
          'hour': newTime.hour,
          'minute': newTime.minute
        };
      }

      await _scheduledTasksRef.doc(taskId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }
}

class LocalStorageService {
  static const String SCHEDULED_TASKS_KEY = 'scheduled_tasks';
  static const String QUICK_TASKS_KEY = 'quick_tasks';
  static late SharedPreferences _prefs;

  // Initialize shared preferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save tasks locally
  static Future<void> saveScheduledTasks(List<TodoItem> tasks) async {
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await _prefs.setString(SCHEDULED_TASKS_KEY, jsonEncode(tasksJson));
  }

  static Future<void> saveQuickTasks(List<QuickTask> tasks) async {
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await _prefs.setString(QUICK_TASKS_KEY, jsonEncode(tasksJson));
  }

  // Get tasks from local storage
  static List<TodoItem> getScheduledTasks() {
    final tasksString = _prefs.getString(SCHEDULED_TASKS_KEY);
    if (tasksString == null) return [];

    final tasksList = jsonDecode(tasksString) as List;
    return tasksList.map((task) => TodoItem.fromJson(task)).toList();
  }

  static List<QuickTask> getQuickTasks() {
    final tasksString = _prefs.getString(QUICK_TASKS_KEY);
    if (tasksString == null) return [];

    final tasksList = jsonDecode(tasksString) as List;
    return tasksList.map((task) => QuickTask.fromJson(task)).toList();
  }
}
