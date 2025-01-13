import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/data/todo_service.dart';

// Storage service class
class TodoStorage {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Update the create todo method to properly format data for Firestore
  Future<void> createTodo(TodoItem todo) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Convert data to Firestore format
      Map<String, dynamic> todoData = {
        'title': todo.title,
        'description': todo.description,
        'createdAt': Timestamp.fromDate(todo.createdAt),
        'dueDate': Timestamp.fromDate(todo.dueDate),
        'dueTime': todo.dueTime != null
            ? '${todo.dueTime!.hour}:${todo.dueTime!.minute}'
            : null,
        'isCompleted': todo.isCompleted,
        'completedAt': todo.completedAt != null
            ? Timestamp.fromDate(todo.completedAt!)
            : null,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .add(todoData);
    } catch (e) {
      print('Error creating todo: $e');
      throw Exception('Failed to create todo: ${e.toString()}');
    }
  }

  // Update the getTodosStream to properly handle the data
  Stream<List<TodoItem>> getTodosStream() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .orderBy('createdAt', descending: true) // Add ordering
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Print for debugging
        print('Document ID: ${doc.id}');
        print('Document data: ${doc.data()}');

        return TodoItem.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> updateTodoStatus(String todoId, bool isCompleted) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(todoId)
          .update({
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      print('Error updating todo status: $e');
      throw Exception('Failed to update todo status: ${e.toString()}');
    }
  }

  Future<void> updateTodoDate(String todoId, DateTime newDate) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(todoId)
          .update({
        'dueDate': Timestamp.fromDate(newDate),
      });
    } catch (e) {
      print('Error updating todo date: $e');
      throw Exception('Failed to update todo date: ${e.toString()}');
    }
  }

  Future<void> deleteTodo(String todoId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First, get the todo data for potential restoration
      final todoDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(todoId)
          .get();

      if (!todoDoc.exists) {
        throw Exception('Todo not found');
      }

      // Store the todo data in SharedPreferences for undo functionality
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'deleted_todo_$todoId',
          jsonEncode({
            'data': todoDoc.data(),
            'timestamp': DateTime.now().toIso8601String(),
          }));

      // Delete the todo
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .doc(todoId)
          .delete();
    } catch (e) {
      print('Error deleting todo: $e');
      throw Exception('Failed to delete todo: ${e.toString()}');
    }
  }

  // Restore a deleted todo
  Future<void> restoreTodo(TodoItem todo) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Convert TodoItem back to Firestore format
      Map<String, dynamic> todoData = {
        'title': todo.title,
        'description': todo.description,
        'createdAt': Timestamp.fromDate(todo.createdAt),
        'dueDate': Timestamp.fromDate(todo.dueDate),
        'dueTime': todo.dueTime != null
            ? '${todo.dueTime!.hour}:${todo.dueTime!.minute}'
            : null,
        'isCompleted': todo.isCompleted,
        'completedAt': todo.completedAt != null
            ? Timestamp.fromDate(todo.completedAt!)
            : null,
      };

      // Restore the todo with its original ID if possible
      if (todo.id.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('todos')
            .doc(todo.id)
            .set(todoData);
      } else {
        // If no ID is available, create a new document
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('todos')
            .add(todoData);
      }

      // Clean up the stored backup from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('deleted_todo_${todo.id}');
    } catch (e) {
      print('Error restoring todo: $e');
      throw Exception('Failed to restore todo: ${e.toString()}');
    }
  }

  // Optional: Clean up old deleted todos from SharedPreferences
  Future<void> cleanupDeletedTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now();

      for (String key in keys) {
        if (key.startsWith('deleted_todo_')) {
          final String? todoJson = prefs.getString(key);
          if (todoJson != null) {
            final todoData = jsonDecode(todoJson);
            final deletedAt = DateTime.parse(todoData['timestamp']);

            // Remove todos deleted more than 24 hours ago
            if (now.difference(deletedAt).inHours > 24) {
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up deleted todos: $e');
    }
  }
}
