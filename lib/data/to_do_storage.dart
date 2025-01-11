import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/data/todo_service.dart';

// Storage service class
class TodoStorage {
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Stream<List<TodoItem>> getTodosStream() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TodoItem.fromJson(doc.data()))
            .toList());
  }

  Future<void> createTodo(TodoItem todo) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .add(todo.toJson());
    } catch (e) {
      print('Error creating todo: $e');
      throw Exception('Failed to create todo: ${e.toString()}');
    }
  }

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get todos collection reference for current user
  CollectionReference get _todosCollection => 
    _firestore.collection('users/${currentUserId}/todos');

  // Create
  // Update todo status
  Future<void> updateTodoStatus(String todoId, bool isCompleted) async {
    await _todosCollection.doc(todoId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? DateTime.now() : null,
    });
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
