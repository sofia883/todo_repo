import 'package:to_do_app/common_imports.dart';

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

  // Change to BehaviorSubject
  static final _quickTasksController =
      BehaviorSubject<List<QuickTask>>.seeded([]);
  static final _scheduledTasksController =
      BehaviorSubject<List<ScheduleTask>>.seeded([]);

  static Stream<List<ScheduleTask>> getScheduledTasksStream() {
    if (!_isAuthenticated) {
      // When the user is not authenticated, use local storage only
      final localTasks = LocalStorageService.getScheduledTasks();
      _scheduledTasksController.add(localTasks); // Emit the tasks in the stream
      return _scheduledTasksController.stream; // Return the stream
    }

    // If the user is authenticated, fetch from Firestore
    if (_isOnline) {
      return _scheduledTasksRef
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .map((snapshot) {
        final tasks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ScheduleTask.fromJson(data);
        }).toList();

        // Update the stream with tasks and save them to local storage
        _scheduledTasksController.add(tasks);
        LocalStorageService.saveScheduledTasks(tasks);
        return tasks;
      });
    } else {
      // If offline, fetch tasks from local storage
      final localTasks = LocalStorageService.getScheduledTasks();
      _scheduledTasksController.add(localTasks);
      return _scheduledTasksController.stream;
    }
  }

  static Stream<List<QuickTask>> getQuickTasksStream() {
    if (!_isAuthenticated) {
      final localTasks = LocalStorageService.getQuickTasks();
      _quickTasksController.add(localTasks);
      return _quickTasksController.stream;
    }

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

        // Add to behavior subject
        _quickTasksController.add(tasks);
        LocalStorageService.saveQuickTasks(tasks);
        return tasks;
      });
    } else {
      final localTasks = LocalStorageService.getQuickTasks();
      _quickTasksController.add(localTasks);
      return _quickTasksController.stream;
    }
  }

  static Future<void> dispose() async {
    await _connectivitySubscription.cancel();
    await _quickTasksController.close();
    await _scheduledTasksController.close();
  }

  static Future<void> updateScheduledTask(ScheduleTask task) async {
    try {
      final userId = await LocalStorageService.getCurrentUserId();
      final updatedTask = task.copyWith(
        userId: userId,
      );

      if (_isAuthenticated && _isOnline) {
        // Update in Firestore if authenticated and online
        await _scheduledTasksRef.doc(task.id).update(updatedTask.toJson());
      }

      // Update in local storage
      final localTasks = LocalStorageService.getScheduledTasks();
      final taskIndex = localTasks.indexWhere((t) => t.id == task.id);

      if (taskIndex != -1) {
        localTasks[taskIndex] = updatedTask;
        await LocalStorageService.saveScheduledTasks(localTasks);
        _scheduledTasksController.add(localTasks);
      } else {
        // If task doesn't exist locally, add it
        localTasks.add(updatedTask);
        await LocalStorageService.saveScheduledTasks(localTasks);
        _scheduledTasksController.add(localTasks);
      }
    } catch (e) {
      print('Failed to update scheduled task: $e');
      throw Exception('Failed to update scheduled task: $e');
    }
  }

  static Future<void> updateQuickTask(QuickTask task) async {
    try {
      final userId = await LocalStorageService.getCurrentUserId();
      final updatedTask = task.copyWith(
        userId: userId,
      );

      if (_isAuthenticated && _isOnline) {
        // Update in Firestore if authenticated and online
        await _quickTasksRef.doc(task.id).update(updatedTask.toJson());
      }

      // Update in local storage
      final localTasks = LocalStorageService.getQuickTasks();
      final taskIndex = localTasks.indexWhere((t) => t.id == task.id);

      if (taskIndex != -1) {
        localTasks[taskIndex] = updatedTask;
        await LocalStorageService.saveQuickTasks(localTasks);
        _quickTasksController.add(localTasks);
      } else {
        // If task doesn't exist locally, add it
        localTasks.add(updatedTask);
        await LocalStorageService.saveQuickTasks(localTasks);
        _quickTasksController.add(localTasks);
      }
    } catch (e) {
      print('Failed to update quick task: $e');
      throw Exception('Failed to update quick task: $e');
    }
  }

  static Future<void> updateScheduledSubtask(
    String taskId,
    String subtaskId,
    bool isCompleted,
  ) async {
    try {
      final localTasks = LocalStorageService.getScheduledTasks();
      final taskIndex = localTasks.indexWhere((t) => t.id == taskId);

      if (taskIndex != -1) {
        final task = localTasks[taskIndex];
        final updatedSubtasks = List<Map<String, dynamic>>.from(task.subtasks);
        final subtaskIndex =
            updatedSubtasks.indexWhere((s) => s['id'] == subtaskId);

        if (subtaskIndex != -1) {
          updatedSubtasks[subtaskIndex]['isCompleted'] = isCompleted;

          // Check if all subtasks are completed
          final allCompleted =
              updatedSubtasks.every((s) => s['isCompleted'] == true);

          final updatedTask = task.copyWith(
            isCompleted: allCompleted,
          );

          // Update locally
          localTasks[taskIndex] = updatedTask;
          await LocalStorageService.saveScheduledTasks(localTasks);
          _scheduledTasksController.add(localTasks);

          // Update in Firestore if authenticated and online
          if (_isAuthenticated && _isOnline) {
            await _scheduledTasksRef.doc(taskId).update({
              'subtasks': updatedSubtasks,
              'isCompleted': allCompleted,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print('Failed to update scheduled subtask: $e');
      throw Exception('Failed to update scheduled subtask: $e');
    }
  }

  static Future<void> updateQuickSubtaskCompletion(
    String taskId,
    String subtaskId,
    bool isCompleted,
  ) async {
    try {
      final localTasks = LocalStorageService.getQuickTasks();
      final taskIndex = localTasks.indexWhere((t) => t.id == taskId);

      if (taskIndex != -1) {
        final task = localTasks[taskIndex];
        final updatedSubtasks = List<Map<String, dynamic>>.from(task.subtasks);
        final subtaskIndex =
            updatedSubtasks.indexWhere((s) => s['id'] == subtaskId);

        if (subtaskIndex != -1) {
          updatedSubtasks[subtaskIndex]['isCompleted'] = isCompleted;

          // Check if all subtasks are completed
          final allCompleted =
              updatedSubtasks.every((s) => s['isCompleted'] == true);

          final updatedTask = task.copyWith(
            isCompleted: allCompleted,
          );

          // Update locally
          localTasks[taskIndex] = updatedTask;
          await LocalStorageService.saveQuickTasks(localTasks);
          _quickTasksController.add(localTasks);

          // Update in Firestore if authenticated and online
          if (_isAuthenticated && _isOnline) {
            await _quickTasksRef.doc(taskId).update({
              'subtasks': updatedSubtasks,
              'isCompleted': allCompleted,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print('Failed to update quick subtask: $e');
      throw Exception('Failed to update quick subtask: $e');
    }
  }

  static Future<void> addScheduledTask(ScheduleTask task) async {
    try {
      final userId = await LocalStorageService.getCurrentUserId();
      final taskWithUserId = task.copyWith(
        userId: userId,
        id: task.id ?? const Uuid().v4(),
        createdAt: DateTime.now(),
      );

      if (_isAuthenticated && _isOnline) {
        // If authenticated and online, save to Firestore
        await _scheduledTasksRef
            .doc(taskWithUserId.id)
            .set(taskWithUserId.toJson());
      } else {
        // If offline, store locally
        final localTasks = LocalStorageService.getScheduledTasks();
        localTasks.add(taskWithUserId);

        // Save locally
        await LocalStorageService.saveScheduledTasks(localTasks);

        // Update the stream to notify listeners of the new task
        _scheduledTasksController.add(localTasks);
      }
    } catch (e) {
      print('Failed to add scheduled task: $e');
      throw Exception('Failed to add scheduled task: $e');
    }
  }

  static Future<void> addQuickTask(QuickTask task) async {
    try {
      final userId = await LocalStorageService.getCurrentUserId();
      final taskWithUserId = task.copyWith(
        userId: userId,
        id: task.id ?? const Uuid().v4(),
        createdAt: DateTime.now(),
      );

      if (_isAuthenticated && _isOnline) {
        await _quickTasksRef
            .doc(taskWithUserId.id)
            .set(taskWithUserId.toJson());
      } else {
        final localTasks = LocalStorageService.getQuickTasks();
        localTasks.add(taskWithUserId);
        await LocalStorageService.saveQuickTasks(localTasks);
        _quickTasksController.add(localTasks);
      }
    } catch (e) {
      print('Failed to add quick task: $e');
      throw Exception('Failed to add quick task: $e');
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

  static Future<void> deleteQuickTask(String taskId) async {
    try {
      // First remove from local storage
      final localTasks = LocalStorageService.getQuickTasks();
      final updatedTasks =
          localTasks.where((task) => task.id != taskId).toList();
      await LocalStorageService.saveQuickTasks(updatedTasks);

      // Update the stream immediately
      _quickTasksController.add(updatedTasks);

      // Then delete from Firebase if online and authenticated
      if (_isAuthenticated && _isOnline) {
        await _quickTasksRef.doc(taskId).delete();
      }
    } catch (e) {
      // Revert local deletion if Firebase deletion fails
      if (_isAuthenticated && _isOnline) {
        final localTasks = LocalStorageService.getQuickTasks();
        await LocalStorageService.saveQuickTasks(localTasks);
        _quickTasksController.add(localTasks);
      }
      throw Exception('Failed to delete quick task: $e');
    }
  }

  // ... existing code ...

  static Future<void> deleteScheduledTask(String taskId) async {
    try {
      // First remove from local storage to prevent sync issues
      final localTasks = LocalStorageService.getScheduledTasks();
      final updatedTasks =
          localTasks.where((task) => task.id != taskId).toList();
      await LocalStorageService.saveScheduledTasks(updatedTasks);

      // Update the stream immediately
      _scheduledTasksController.add(updatedTasks);

      // Then delete from Firebase if online
      if (_isAuthenticated && _isOnline) {
        await _scheduledTasksRef.doc(taskId).delete();
      }
    } catch (e) {
      // Revert local deletion if Firebase deletion fails
      if (_isAuthenticated && _isOnline) {
        final localTasks = LocalStorageService.getScheduledTasks();
        await LocalStorageService.saveScheduledTasks(localTasks);
        _scheduledTasksController.add(localTasks);
      }
      throw Exception('Failed to delete scheduled task: $e');
    }
  }

  static Future<void> syncWithServer() async {
    if (!_isOnline || !_isAuthenticated) return;

    try {
      // Get the current server state first
      final serverSnapshot = await _scheduledTasksRef.get();
      final serverTasks = serverSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ScheduleTask.fromJson(data);
      }).toList();

      // Get local tasks
      final localTasks = LocalStorageService.getScheduledTasks();

      // Create sets of IDs for comparison
      final serverIds = Set.from(serverTasks.map((t) => t.id));
      final localIds = Set.from(localTasks.map((t) => t.id));

      // Find tasks that need to be synced
      final tasksToUpload =
          localTasks.where((task) => !serverIds.contains(task.id));
      final tasksToDelete =
          serverTasks.where((task) => !localIds.contains(task.id));

      // Batch operations
      final batch = _firestore.batch();

      // Upload new local tasks
      for (var task in tasksToUpload) {
        final taskWithUserId = task.copyWith(userId: _userId);
        final docRef = _scheduledTasksRef.doc(task.id);
        batch.set(docRef, taskWithUserId.toJson());
      }

      // Delete tasks that were removed locally
      for (var task in tasksToDelete) {
        final docRef = _scheduledTasksRef.doc(task.id);
        batch.delete(docRef);
      }

      // Commit all changes
      await batch.commit();
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  // Delete local data on logout
  // In your FirebaseTaskService or a dedicated AuthService class:
  static Future<void> logoutAndClearLocalData(BuildContext context) async {
    try {
      // Sign out the user
      await FirebaseAuth.instance.signOut();

      // Clear local storage
      await LocalStorageService.clear();

      // Navigate to the login screen and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print('Error during logout: $e');
      // Optionally, show an error message to the user
    }
  }

  static bool get _isAuthenticated => _auth.currentUser != null;
  static Future<void> deleteAllData() async {
    try {
      // Delete local data first
      await LocalStorageService.clear();

      // If user is authenticated and online, delete Firebase data
      if (_isAuthenticated && _isOnline) {
        final userId = _auth.currentUser!.uid;
        final userRef = _firestore.collection('users').doc(userId);

        // Delete all scheduled tasks using batch
        final scheduledTasksSnapshot = await _scheduledTasksRef.get();
        final quickTasksSnapshot = await _quickTasksRef.get();

        // Use batched writes for better performance
        final batch = _firestore.batch();

        // Add scheduled tasks deletion to batch
        for (var doc in scheduledTasksSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Add quick tasks deletion to batch
        for (var doc in quickTasksSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Commit the batch
        await batch.commit();

        print('All data deleted successfully');
      }
    } catch (e) {
      print('Failed to delete all data: $e');
      throw Exception('Failed to delete all data: $e');
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
  static Future<void> saveScheduledTasks(List<ScheduleTask> tasks) async {
    final key = '${SCHEDULED_TASKS_KEY}_${await getCurrentUserId()}';
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await _prefs.setString(key, jsonEncode(tasksJson));
  }

  // Get scheduled tasks
  static List<ScheduleTask> getScheduledTasks() {
    final userId = _prefs.getString(LOCAL_USER_ID_KEY) ?? '';
    final key = '${SCHEDULED_TASKS_KEY}_$userId';
    final tasksString = _prefs.getString(key);
    if (tasksString == null) return [];
    final tasksList = jsonDecode(tasksString) as List;
    return tasksList.map((task) => ScheduleTask.fromJson(task)).toList();
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
    await _prefs.clear();

    // Optionally, clear the local user ID if desired
    await _prefs.remove(LOCAL_USER_ID_KEY);
  }
}
