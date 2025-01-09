import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/services/todo_service.dart';

// Storage service class
class TodoStorage {
  static const String _key = 'todos';

  static Future<void> saveTodos(List<TodoItem> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final String todosJson = json.encode(
      todos.map((todo) => todo.toJson()).toList(),
    );
    await prefs.setString(_key, todosJson);
  }

  static Future<List<TodoItem>> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString(_key);
    if (todosJson == null) return [];

    final List<dynamic> todosList = json.decode(todosJson);
    return todosList.map((json) => TodoItem.fromJson(json)).toList();
  }

  static const String _storageKey = 'todo_lists';

  // Load all todo lists
  static Future<List<TodoListData>> loadTodoLists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => TodoListData.fromJson(json)).toList();
  }

  // Save all todo lists
  static Future<void> saveTodoLists(List<TodoListData> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(lists.map((list) => list.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

// Update Todo List
  static Future<void> updateTodoList(TodoListData updatedList) async {
    final lists = await loadTodoLists();
    final index = lists.indexWhere((list) => list.title == updatedList.title);
    if (index != -1) {
      lists[index] = updatedList;
      await saveTodoLists(lists);
    }
  }

// Delete Todo List
  static Future<void> deleteTodoList(String title) async {
    final lists = await loadTodoLists();
    lists.removeWhere((list) => list.title == title);
    await saveTodoLists(lists);
  }
}
