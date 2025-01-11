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

  // Get todos collection reference for current user
  CollectionReference get _todosCollection =>
      _firestore.collection('users/${currentUserId}/todos');

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

    // Get overdue todos
    Stream<List<TodoItem>> getOverdueTodos() {
      final now = DateTime.now();
      return _todosCollection
          .where('isCompleted', isEqualTo: false)
          .where('dueDate', isLessThan: now)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return TodoItem.fromFirestore(doc.id, data);
        }).toList();
      });
    }

    // Undo task completion
    Future<void> undoTaskCompletion(String todoId) async {
      await _todosCollection.doc(todoId).update({
        'isCompleted': false,
        'completedAt': null,
      });
    }
  }
}
