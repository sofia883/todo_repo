import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Update TodoItem class to support JSON serialization
class TodoItem {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime dueDate;
  final TimeOfDay? dueTime;
  bool isCompleted;
  DateTime? completedAt;

  TodoItem({
    this.id = '',
    required this.title,
    required this.description,
    required this.createdAt,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.completedAt,
  });

  factory TodoItem.fromFirestore(String id, Map<String, dynamic> data) {
    TimeOfDay? dueTime;
    if (data['dueTime'] != null) {
      final timeParts = data['dueTime'].split(':');
      dueTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }

    return TodoItem(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      dueTime: dueTime,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  static TodoItem fromJson(Map<String, dynamic> json) {
    TimeOfDay? dueTime;
    if (json['dueTime'] != null) {
      final timeParts = json['dueTime'].split(':');
      dueTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }

    return TodoItem(
      title: json['title'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: DateTime.parse(json['dueDate']),
      dueTime: dueTime,
      isCompleted: json['isCompleted'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}

// Model class for TodoListData
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
