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
      await HybridStorageService.updateQuickTaskCompletion(
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
      await HybridStorageService.updateQuickSubtaskCompletion(
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

// Authentication Service
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email and password
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

class HybridStorageService {
  static final HybridStorageService _instance =
      HybridStorageService._internal();
  factory HybridStorageService() => _instance;
  HybridStorageService._internal();

  static final _scheduledTasksController =
      StreamController<List<TodoItem>>.broadcast();
  static final _quickTasksController =
      StreamController<List<QuickTask>>.broadcast();

  // Add initialized flag
  bool _isInitialized = false;

  // Initialize method that should be called in main.dart or app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load local data immediately
      final localScheduledTasks = await _loadLocalScheduledTasks();
      final localQuickTasks = await _loadLocalQuickTasks();

      // Update cache and emit immediately
      _scheduledTasksCache = localScheduledTasks;
      _quickTasksCache = localQuickTasks;

      // Emit initial data right away
      _scheduledTasksController.add(_scheduledTasksCache);
      _quickTasksController.add(_quickTasksCache);

      // Set up connectivity listener
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none) {
          _syncWithFirebase();
        }
      });

      // Try Firebase sync in background
      _syncWithFirebase();

      _isInitialized = true;
    } catch (e) {
      print('Error initializing HybridStorageService: $e');
      // Even if Firebase fails, we still have local data
    }
  }

  // Optimized load methods that return cached data immediately if available
  static Future<List<TodoItem>> loadScheduledTasks() async {
    if (!_instance._isInitialized) {
      await _instance.initialize();
    }
    return _scheduledTasksCache;
  }

  static Future<List<QuickTask>> loadQuickTasks() async {
    if (!_instance._isInitialized) {
      await _instance.initialize();
    }
    return _quickTasksCache;
  }

  // Modified sync method with better error handling
  static Future<void> _syncWithFirebase() async {
    if (_auth.currentUser == null) return;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return;

      // Use Future.wait to run both Firebase queries in parallel
      final futures = await Future.wait([
        _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('quick_tasks')
            .get(),
        _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('scheduled_tasks')
            .get(),
      ]);

      // Process quick tasks
      final quickTasks =
          futures[0].docs.map((doc) => QuickTask.fromJson(doc.data())).toList();

      // Process scheduled tasks
      final scheduledTasks =
          futures[1].docs.map((doc) => TodoItem.fromJson(doc.data())).toList();

      // Update both caches and storage in parallel
      await Future.wait([
        _saveLocalQuickTasks(quickTasks),
        _saveLocalScheduledTasks(scheduledTasks),
      ]);

      // Update cache and notify
      _quickTasksCache = quickTasks;
      _scheduledTasksCache = scheduledTasks;

      _quickTasksController.add(quickTasks);
      _scheduledTasksController.add(scheduledTasks);
    } catch (e) {
      print('Firebase sync failed: $e');
      // Continue with local data
    }
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  static final _pendingOperations = <Map<String, dynamic>>[];

  static const String _scheduledTasksKey = 'scheduled_tasks';
  static const String _quickTasksKey = 'quick_tasks';
  static const String _pendingOperationsKey = 'pending_operations';

  // Cache for immediate access
  static List<TodoItem> _scheduledTasksCache = [];
  static List<QuickTask> _quickTasksCache = [];
  static Stream<List<TodoItem>> get scheduledTasksStream =>
      _scheduledTasksController.stream;
  static Stream<List<QuickTask>> get quickTasksStream =>
      _quickTasksController.stream;

  // Optimized Quick Task methods
  static Future<void> addQuickTask(QuickTask task) async {
    // Update cache and notify immediately
    _quickTasksCache.add(task);
    _quickTasksController.add(_quickTasksCache);

    // Save locally
    await _saveLocalQuickTasks(_quickTasksCache);

    // Try Firebase in background
    _firebaseAddQuickTask(task);
  }

  static Future<void> deleteQuickTask(String taskId) async {
    // Update cache and notify immediately
    _quickTasksCache.removeWhere((task) => task.id == taskId);
    _quickTasksController.add(_quickTasksCache);

    // Save locally
    await _saveLocalQuickTasks(_quickTasksCache);

    // Try Firebase in background
    _firebaseDeleteQuickTask(taskId);
  }

  static Future<void> updateQuickTask(QuickTask task) async {
    // Update cache and notify immediately
    final index = _quickTasksCache.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _quickTasksCache[index] = task;
      _quickTasksController.add(_quickTasksCache);
    }

    // Save locally
    await _saveLocalQuickTasks(_quickTasksCache);

    // Try Firebase in background
    _firebaseUpdateQuickTask(task);
  }

  // Optimized Scheduled Task methods
  static Future<void> addScheduledTask(TodoItem task) async {
    // Update cache and notify immediately
    _scheduledTasksCache.add(task);
    _scheduledTasksController.add(_scheduledTasksCache);

    // Save locally
    await _saveLocalScheduledTasks(_scheduledTasksCache);

    // Try Firebase in background
    _firebaseAddScheduledTask(task);
  }

  static Future<void> deleteScheduledTask(String taskId) async {
    // Update cache and notify immediately
    _scheduledTasksCache.removeWhere((task) => task.id == taskId);
    _scheduledTasksController.add(_scheduledTasksCache);

    // Save locally
    await _saveLocalScheduledTasks(_scheduledTasksCache);

    // Try Firebase in background
    _firebaseDeleteScheduledTask(taskId);
  }

  static Future<void> updateScheduledTask(TodoItem task) async {
    // Update cache and notify immediately
    final index = _scheduledTasksCache.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _scheduledTasksCache[index] = task;
      _scheduledTasksController.add(_scheduledTasksCache);
    }

    // Save locally
    await _saveLocalScheduledTasks(_scheduledTasksCache);

    // Try Firebase in background
    _firebaseUpdateScheduledTask(task);
  }

  // Add similar _firebaseXXX methods for other operations...

  // Expose streams for UI
  static Stream<List<TodoItem>> getScheduledTasksStream() =>
      _scheduledTasksController.stream;
  static Stream<List<QuickTask>> getQuickTasksStream() =>
      _quickTasksController.stream;

  // Quick Tasks Methods
  static Future<List<QuickTask>> _loadLocalQuickTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_quickTasksKey);
    if (tasksJson == null) return [];

    final List<dynamic> decoded = json.decode(tasksJson);
    return decoded.map((item) => QuickTask.fromJson(item)).toList();
  }

  static Future<void> _saveLocalQuickTasks(List<QuickTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedTasks =
        json.encode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_quickTasksKey, encodedTasks);
  }

  static Future<void> updateQuickTaskCompletion(
      String taskId, bool isCompleted) async {
    try {
      // Update locally
      final tasks = await _loadLocalQuickTasks();
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        tasks[index] = tasks[index].copyWith(isCompleted: isCompleted);
        await _saveLocalQuickTasks(tasks);
      }

      // Update Firebase if online
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('quick_tasks')
            .doc(taskId)
            .update({
          'isCompleted': isCompleted,
          'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
        });
      } else {
        _addPendingOperation({
          'type': 'update_quick_completion',
          'taskId': taskId,
          'isCompleted': isCompleted,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      _quickTasksController.add(tasks);
    } catch (e) {
      print('Error updating quick task completion: $e');
      rethrow;
    }
  }

  static Future<void> updateQuickSubtaskCompletion(
    String taskId,
    String subtaskId,
    bool isCompleted,
  ) async {
    try {
      // Update locally
      final tasks = await _loadLocalQuickTasks();
      final taskIndex = tasks.indexWhere((t) => t.id == taskId);

      if (taskIndex != -1) {
        final task = tasks[taskIndex];
        final updatedSubtasks = task.subtasks
            .map((subtask) => subtask.id == subtaskId
                ? subtask.copyWith(isCompleted: isCompleted)
                : subtask)
            .toList();

        final allCompleted =
            updatedSubtasks.every((subtask) => subtask.isCompleted);
        tasks[taskIndex] = task.copyWith(
          subtasks: updatedSubtasks,
          isCompleted: allCompleted,
        );

        await _saveLocalQuickTasks(tasks);
      }

      // Update Firebase if online
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        final taskDoc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('quick_tasks')
            .doc(taskId)
            .get();

        if (taskDoc.exists) {
          final taskData = taskDoc.data()!;
          final subtasks =
              List<Map<String, dynamic>>.from(taskData['subtasks']);

          final subtaskIndex = subtasks.indexWhere((s) => s['id'] == subtaskId);
          if (subtaskIndex != -1) {
            subtasks[subtaskIndex]['isCompleted'] = isCompleted;

            final allCompleted =
                subtasks.every((s) => s['isCompleted'] == true);

            await taskDoc.reference.update({
              'subtasks': subtasks,
              'isCompleted': allCompleted,
            });
          }
        }
      } else {
        _addPendingOperation({
          'type': 'update_quick_subtask',
          'taskId': taskId,
          'subtaskId': subtaskId,
          'isCompleted': isCompleted,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      _quickTasksController.add(tasks);
    } catch (e) {
      print('Error updating quick subtask completion: $e');
      rethrow;
    }
  }

  // Scheduled Tasks Methods
  static Future<void> updateRescheduleScheduledTask(
    String taskId,
    DateTime newDate,
    TimeOfDay? newTime,
  ) async {
    try {
      // Update locally
      final tasks = await _loadLocalScheduledTasks();
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        tasks[index] = TodoItem(
          id: tasks[index].id,
          title: tasks[index].title,
          description: tasks[index].description,
          createdAt: tasks[index].createdAt,
          dueDate: newDate,
          dueTime: newTime,
          isCompleted: tasks[index].isCompleted,
          completedAt: tasks[index].completedAt,
          subtasks: tasks[index].subtasks,
        );
        await _saveLocalScheduledTasks(tasks);
      }

      // Update Firebase if online
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        Map<String, dynamic> updateData = {
          'dueDate': newDate.toIso8601String(),
        };

        if (newTime != null) {
          updateData['dueTime'] = {
            'hour': newTime.hour,
            'minute': newTime.minute
          };
        }

        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('scheduled_tasks')
            .doc(taskId)
            .update(updateData);
      } else {
        _addPendingOperation({
          'type': 'reschedule_task',
          'taskId': taskId,
          'newDate': newDate.toIso8601String(),
          'newTime': newTime != null
              ? {'hour': newTime.hour, 'minute': newTime.minute}
              : null,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      _scheduledTasksController.add(tasks);
    } catch (e) {
      print('Error rescheduling task: $e');
      rethrow;
    }
  }

  // Helper methods for local storage
  static Future<List<TodoItem>> _loadLocalScheduledTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_scheduledTasksKey);
    if (tasksJson == null) return [];

    final List<dynamic> decoded = json.decode(tasksJson);
    return decoded.map((item) => TodoItem.fromJson(item)).toList();
  }

  static Future<void> _saveLocalScheduledTasks(List<TodoItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedTasks =
        json.encode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_scheduledTasksKey, encodedTasks);
  }

  static Future<void> _firebaseAddQuickTask(QuickTask task) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('quick_tasks')
            .doc(task.id)
            .set(task.toJson());
      } else {
        _addPendingOperation({
          'type': 'add_quick',
          'data': task.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Background Firebase add quick task failed: $e');
    }
  }

  static Future<void> _firebaseDeleteQuickTask(String taskId) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('quick_tasks')
            .doc(taskId)
            .delete();
      } else {
        _addPendingOperation({
          'type': 'delete_quick',
          'taskId': taskId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Background Firebase delete quick task failed: $e');
    }
  }

  static Future<void> _firebaseUpdateQuickTask(QuickTask task) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('quick_tasks')
            .doc(task.id)
            .update(task.toJson());
      } else {
        _addPendingOperation({
          'type': 'update_quick',
          'data': task.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Background Firebase update quick task failed: $e');
    }
  }

  // Background Firebase operations for Scheduled Tasks
  static Future<void> _firebaseAddScheduledTask(TodoItem task) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('scheduled_tasks')
            .doc(task.id)
            .set(task.toJson());
      } else {
        _addPendingOperation({
          'type': 'add_scheduled',
          'data': task.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Background Firebase add scheduled task failed: $e');
    }
  }

  static Future<void> _firebaseDeleteScheduledTask(String taskId) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('scheduled_tasks')
            .doc(taskId)
            .delete();
      } else {
        _addPendingOperation({
          'type': 'delete_scheduled',
          'taskId': taskId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Background Firebase delete scheduled task failed: $e');
    }
  }

  static Future<void> _firebaseUpdateScheduledTask(TodoItem task) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none &&
          _auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('scheduled_tasks')
            .doc(task.id)
            .update(task.toJson());
      } else {
        _addPendingOperation({
          'type': 'update_scheduled',
          'data': task.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Background Firebase update scheduled task failed: $e');
    }
  }

  // Update sync method to handle new quick task operations
  Future<void> _syncPendingOperations() async {
    if (_auth.currentUser == null || _pendingOperations.isEmpty) return;

    final operations = List<Map<String, dynamic>>.from(_pendingOperations);
    _pendingOperations.clear();

    for (final operation in operations) {
      try {
        switch (operation['type']) {
          case 'add_scheduled':
          case 'add_quick':
            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .collection(operation['type'] == 'add_scheduled'
                    ? 'scheduled_tasks'
                    : 'quick_tasks')
                .doc(operation['data']['id'])
                .set(operation['data']);
            break;

          case 'update_quick':
            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .collection('quick_tasks')
                .doc(operation['data']['id'])
                .update(operation['data']);
            break;

          case 'update_quick_completion':
            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .collection('quick_tasks')
                .doc(operation['taskId'])
                .update({
              'isCompleted': operation['isCompleted'],
              'completedAt': operation['isCompleted']
                  ? FieldValue.serverTimestamp()
                  : null,
            });
            break;

          case 'update_quick_subtask':
            final taskDoc = await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .collection('quick_tasks')
                .doc(operation['taskId'])
                .get();

            if (taskDoc.exists) {
              final taskData = taskDoc.data()!;
              final subtasks =
                  List<Map<String, dynamic>>.from(taskData['subtasks']);
              final subtaskIndex =
                  subtasks.indexWhere((s) => s['id'] == operation['subtaskId']);

              if (subtaskIndex != -1) {
                subtasks[subtaskIndex]['isCompleted'] =
                    operation['isCompleted'];
                final allCompleted =
                    subtasks.every((s) => s['isCompleted'] == true);

                await taskDoc.reference.update({
                  'subtasks': subtasks,
                  'isCompleted': allCompleted,
                });
              }
            }
            break;

          case 'reschedule_task':
            Map<String, dynamic> updateData = {
              'dueDate': operation['newDate'],
            };
            if (operation['newTime'] != null) {
              updateData['dueTime'] = operation['newTime'];
            }

            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .collection('scheduled_tasks')
                .doc(operation['taskId'])
                .update(updateData);
            break;

          case 'delete_quick':
            await _firestore
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .collection('quick_tasks')
                .doc(operation['taskId'])
                .delete();
            break;
        }
      } catch (e) {
        print('Error syncing operation: $e');
        _pendingOperations.add(operation);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _pendingOperationsKey, json.encode(_pendingOperations));
  }

  // Pending operations management
  static Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString(_pendingOperationsKey);
    if (pendingJson != null) {
      final List<dynamic> decoded = json.decode(pendingJson);
      _pendingOperations.addAll(decoded.cast<Map<String, dynamic>>());
    }
  }

  static void _addPendingOperation(Map<String, dynamic> operation) async {
    _pendingOperations.add(operation);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _pendingOperationsKey, json.encode(_pendingOperations));
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _scheduledTasksController.close();
    _quickTasksController.close();
  }
}
