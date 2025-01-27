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
import 'package:uuid/uuid.dart';

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
  final String userId; // Added userId field

  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime dueDate;
  final TimeOfDay? dueTime;

  bool isSubtasksExpanded = false;
  bool isOverdue = false;
  final bool isQuickTask; // Added isQuickTask field
  bool isCompleted;

  DateTime? completedAt;
  List<SubTask> subtasks; // Added subtasks field

  TodoItem({
    required this.id,
    required this.userId, // Initialize userId
    required this.title,
    required this.description,
    required this.createdAt,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.isQuickTask = false, // Default to false
    this.completedAt,
    this.subtasks = const [], // Default empty list for subtasks
  });

  /// Convert a `TodoItem` instance to a JSON map
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

  /// Create a `TodoItem` instance from a JSON map
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
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
              ?.map((subtask) => SubTask.fromJson(subtask))
              .toList() ??
          [],
    );
  }

  /// Create a copy of the current `TodoItem` with optional updated fields
  TodoItem copyWith({
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
    List<SubTask>? subtasks,
  }) {
    return TodoItem(
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
  final String userId; // Add the userId field
  final String title;
  final DateTime createdAt;
  final List<QuickSubTask> subtasks;
  bool? isCompleted;

  QuickTask({
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

  factory QuickTask.fromJson(Map<String, dynamic> json) {
    return QuickTask(
      id: json['id'],
      userId: json['userId'] ?? '',
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
    String? userId,
    String? title,
    DateTime? createdAt,
    List<QuickSubTask>? subtasks,
    bool? isCompleted,
  }) {
    return QuickTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
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

  // Connectivity subscription
  static late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  // Get the current user ID
  static String get _userId {
    return _auth.currentUser?.uid ?? 'guest_user';
  }

  // Initialize offline storage
  static Future<void> initializeOfflineStorage() async {
    await _firestore.enablePersistence();
    await LocalStorageService.init();

    _connectivitySubscription = Connectivity()
            .onConnectivityChanged
            .listen((ConnectivityResult result) {
              _isOnline = result != ConnectivityResult.none;
              if (_isOnline) {
                syncWithServer(); // Sync data when the network becomes available
              }
            } as void Function(List<ConnectivityResult> event)?)
        as StreamSubscription<ConnectivityResult>;
  }

  // Dispose connectivity subscription
  static Future<void> dispose() async {
    await _connectivitySubscription.cancel();
  }

  // Add scheduled task with user ID
  static Future<void> addScheduledTask(TodoItem task) async {
    final taskWithUserId = task.copyWith(userId: _userId);

    try {
      if (_isOnline) {
        await _scheduledTasksRef.doc(task.id).set(taskWithUserId.toJson());
      }
      final localTasks = LocalStorageService.getScheduledTasks();
      localTasks.add(taskWithUserId);
      await LocalStorageService.saveScheduledTasks(localTasks);
    } catch (e) {
      // Save locally on failure
      final localTasks = LocalStorageService.getScheduledTasks();
      localTasks.add(taskWithUserId);
      await LocalStorageService.saveScheduledTasks(localTasks);
    }
  }

  static Stream<List<TodoItem>> getScheduledTasksStream() {
    if (_isOnline) {
      return _scheduledTasksRef
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .map((snapshot) {
        final tasks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return TodoItem.fromJson(data);
        }).toList();
        LocalStorageService.saveScheduledTasks(
            tasks); // Sync with local storage
        return tasks;
      });
    } else {
      return Stream.value(
          LocalStorageService.getScheduledTasks()); // Offline fallback
    }
  }

  // Add quick task with user ID
  static Future<void> addQuickTask(QuickTask task) async {
    final taskWithUserId = task.copyWith(userId: _userId);

    try {
      if (_isOnline) {
        await _quickTasksRef.doc(task.id).set(taskWithUserId.toJson());
      }
      final localTasks = LocalStorageService.getQuickTasks();
      localTasks.add(taskWithUserId);
      await LocalStorageService.saveQuickTasks(localTasks);
    } catch (e) {
      // Save locally on failure
      final localTasks = LocalStorageService.getQuickTasks();
      localTasks.add(taskWithUserId);
      await LocalStorageService.saveQuickTasks(localTasks);
    }
  }

  // Stream quick tasks
  static Stream<List<QuickTask>> getQuickTasksStream() {
    if (_isOnline) {
      return _quickTasksRef
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .map((snapshot) {
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

  // Sync with server
  static Future<void> syncWithServer() async {
    if (!_isOnline) return;

    try {
      // Sync scheduled tasks
      final localScheduledTasks = LocalStorageService.getScheduledTasks();
      for (var task in localScheduledTasks) {
        final taskWithUserId = task.copyWith(userId: _userId);
        await _scheduledTasksRef.doc(task.id).set(taskWithUserId.toJson());
      }

      // Sync quick tasks
      final localQuickTasks = LocalStorageService.getQuickTasks();
      for (var task in localQuickTasks) {
        final taskWithUserId = task.copyWith(userId: _userId);
        await _quickTasksRef.doc(task.id).set(taskWithUserId.toJson());
      }
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  static Future<void> updateQuickTaskCompletion(
      String taskId, bool isCompleted) async {
    await _quickTasksRef.doc(taskId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
      'userId': _userId, // Ensure userId is included
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
    String taskId,
    DateTime newDate,
    TimeOfDay? newTime,
  ) async {
    try {
      // Create a map of fields to update
      Map<String, dynamic> updateData = {
        'dueDate': newDate.toIso8601String(),
      };

      // Only include dueTime if it's provided
      if (newTime != null) {
        updateData['dueTime'] = {
          'hour': newTime.hour,
          'minute': newTime.minute,
        };
      }

      // Update the task in Firestore
      await _scheduledTasksRef.doc(taskId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  static Future<void> updateQuickTask(QuickTask task) async {
    try {
      await _quickTasksRef.doc(task.id).update(task.toJson());
    } catch (e) {
      throw Exception('Failed to update quick task: $e');
    }
  }

  static Future<void> deleteQuickTask(String taskId) async {
    try {
      await _quickTasksRef.doc(taskId).delete();
    } catch (e) {
      throw Exception('Failed to delete quick task: $e');
    }
  }

  static Future<void> updateScheduledTask(TodoItem task) async {
    try {
      await _scheduledTasksRef.doc(task.id).update(task.toJson());
    } catch (e) {
      throw Exception('Failed to update scheduled task: $e');
    }
  }

  static Future<void> deleteScheduledTask(String taskId) async {
    try {
      await _scheduledTasksRef.doc(taskId).delete();
    } catch (e) {
      throw Exception('Failed to delete scheduled task: $e');
    }
  }

  // Delete local data on logout
  static Future<void> logoutAndClearLocalData() async {
    try {
      await _auth.signOut(); // Log out the user
      await LocalStorageService.clear(); // Clear only local data on the device
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  static Future<void> deleteUserDataAndAccount() async {
    try {
      // Get the current user
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        throw Exception('No authenticated user found.');
      }

      final userId = currentUser.uid;

      // Step 1: Delete Firestore data for the user
      // Firebase collections for the user
      final scheduledTasksRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('scheduled_tasks');
      final quickTasksRef =
          _firestore.collection('users').doc(userId).collection('quick_tasks');

      // Delete all scheduled tasks in Firestore
      final scheduledTasksQuery = await scheduledTasksRef.get();
      for (var doc in scheduledTasksQuery.docs) {
        await doc.reference.delete();
      }

      // Delete all quick tasks in Firestore
      final quickTasksQuery = await quickTasksRef.get();
      for (var doc in quickTasksQuery.docs) {
        await doc.reference.delete();
      }

      // Delete the user's main Firestore document (if exists)
      final userDocRef = _firestore.collection('users').doc(userId);
      await userDocRef.delete();

      // Step 2: Delete the user from Firebase Authentication
      await currentUser.delete();

      // Step 3: Clear local data
      await LocalStorageService.clear();

      print('User and all associated data deleted successfully.');
    } catch (e) {
      print('Failed to delete user data and account: $e');
      throw Exception('Failed to delete user data and account: $e');
    }
  }

  // Firebase references
  static CollectionReference get _scheduledTasksRef =>
      _firestore.collection('users').doc(_userId).collection('scheduled_tasks');

  static CollectionReference get _quickTasksRef =>
      _firestore.collection('users').doc(_userId).collection('quick_tasks');
}

class LocalStorageService {
  static const String SCHEDULED_TASKS_KEY = 'scheduled_tasks';
  static const String QUICK_TASKS_KEY = 'quick_tasks';
  static late SharedPreferences _prefs;
  static const String LOCAL_USER_ID_KEY = 'local_user_id';

  // Get current user ID
  static Future<String> getCurrentUserId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return currentUser.uid; // Authenticated user ID
    }

    // Generate unique local ID for guest users
    String? localUserId = _prefs.getString(LOCAL_USER_ID_KEY);
    if (localUserId == null) {
      localUserId = const Uuid().v4();
      await _prefs.setString(LOCAL_USER_ID_KEY, localUserId);
    }
    return localUserId;
  }

  // Initialize shared preferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save scheduled tasks
  static Future<void> saveScheduledTasks(List<TodoItem> tasks) async {
    final key = '${SCHEDULED_TASKS_KEY}_${await getCurrentUserId()}';
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await _prefs.setString(key, jsonEncode(tasksJson));
  }

  // Get scheduled tasks
  static List<TodoItem> getScheduledTasks() {
    final userId = _prefs.getString(LOCAL_USER_ID_KEY) ?? '';
    final key = '${SCHEDULED_TASKS_KEY}_$userId';
    final tasksString = _prefs.getString(key);
    if (tasksString == null) return [];
    final tasksList = jsonDecode(tasksString) as List;
    return tasksList.map((task) => TodoItem.fromJson(task)).toList();
  }

  // Save quick tasks
  static Future<void> saveQuickTasks(List<QuickTask> tasks) async {
    final key = '${QUICK_TASKS_KEY}_${await getCurrentUserId()}';
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await _prefs.setString(key, jsonEncode(tasksJson));
  }

  // Get quick tasks
  static List<QuickTask> getQuickTasks() {
    final userId = _prefs.getString(LOCAL_USER_ID_KEY) ?? '';
    final key = '${QUICK_TASKS_KEY}_$userId';
    final tasksString = _prefs.getString(key);
    if (tasksString == null) return [];
    final tasksList = jsonDecode(tasksString) as List;
    return tasksList.map((task) => QuickTask.fromJson(task)).toList();
  }

  static Future<void> clear() async {
    final userId = _prefs.getString(LOCAL_USER_ID_KEY) ?? '';
    final scheduledTasksKey = '${SCHEDULED_TASKS_KEY}_$userId';
    final quickTasksKey = '${QUICK_TASKS_KEY}_$userId';

    // Remove data for guest user
    await _prefs.remove(scheduledTasksKey);
    await _prefs.remove(quickTasksKey);

    // Optionally, clear the local user ID if desired
    await _prefs.remove(LOCAL_USER_ID_KEY);
  }
}
