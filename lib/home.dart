import 'package:flutter/material.dart';
import 'todo_screen.dart';
import 'todo_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TodoListData> todoLists = [];
  late TextEditingController titleController;
  bool isTitleEditing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTodoLists();
  }

  Future<void> _loadSavedTodoLists() async {
    final savedLists = await TodoStorage.loadTodoLists();
    setState(() {
      todoLists = savedLists;
    });
  }

  Future<void> _saveTodoLists() async {
    await TodoStorage.saveTodoLists(todoLists);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('My Todo Lists'),
          backgroundColor: Colors.pink[100],
          elevation: 0,
        ),
        // Add a gradient background
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.pink[50]!,
                Colors.pink[100]!,
              ],
            ),
          ),
          child: GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: todoLists.length + 1, // +1 for the "Add" button
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddButton();
              }
              return _buildTodoCard(todoLists[index - 1]);
            },
          ),
        ));
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TodoList()),
        );
        if (result != null && result.todos.isNotEmpty) {
          setState(() {
            todoLists.add(result);
          });
          await _saveTodoLists(); // Save after adding new list
        }
      },
      child: Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: SizedBox(
          height: 80, // Reduced height for the add button
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 48,
                color: Colors.pink[300],
              ),
              SizedBox(height: 8),
              Text(
                'Quick Add',
                style: TextStyle(
                  color: Colors.pink[300],
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoCard(TodoListData todoList) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TodoList(
                existingTodoList: todoList,
                todoListData: TodoListData(
                  category: todoList.category,
                  categoryColor: todoList.categoryColor,
                  title: todoList.title,
                  todos: todoList.todos,
                ),
              ),
            ));
        if (result != null) {
          setState(() {
            int index = todoLists.indexOf(todoList);
            todoLists[index] = result;
          });
          await _saveTodoLists();
        }
      },
      onLongPress: () async {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Choose an option'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(todoList);
                  },
                  child: Text('Delete'),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() {
                      for (var todo in todoList.todos) {
                        todo.isCompleted = true;
                        todo.completedAt = DateTime.now();
                      }
                    });
                    await _saveTodoLists();
                    Navigator.pop(context);
                  },
                  child: Text('Mark All Completed'),
                ),
              ],
            );
          },
        );
      },
      child: Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todoList.title.isNotEmpty ? todoList.title : 'Untitled',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color:
                      todoList.categoryColor, // Use the list's category color
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _getPreviewItemCount(todoList.todos),
                  itemBuilder: (context, index) {
                    if (index < 2) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 14, // Smaller circle size
                              height: 14, // Smaller circle size
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: todoList.todos[index].isCompleted
                                      ? Colors.pink[400]!
                                      : Colors.pink[200]!,
                                ),
                                color: todoList.todos[index].isCompleted
                                    ? Colors.pink[400]
                                    : Colors.transparent,
                              ),
                              child: todoList.todos[index].isCompleted
                                  ? Icon(Icons.check,
                                      size: 10, color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                todoList.todos[index].text,
                                style: TextStyle(
                                  decoration: todoList.todos[index].isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: todoList.todos[index].isCompleted
                                      ? Colors.pink[400]
                                      : Colors.pink[900],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (index == 2 && todoList.todos.length > 2) {
                      // Calculate remaining todos
                      int remainingTodos = todoList.todos.length - 2;
                      return Padding(
                        padding: EdgeInsets.only(
                            top: 16, left: 4), // Added padding to create space
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+$remainingTodos more',
                            style: TextStyle(
                              color: Colors.pink[300],
                              fontSize: 14, // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }
                    return SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getPreviewItemCount(List<TodoItem> todos) {
    if (todos.isEmpty) return 0;
    return todos.length > 2 ? 3 : todos.length;
  }

  Future<void> _showDeleteConfirmation(TodoListData todoList) async {
    // Check if there are any incomplete todos
    bool hasIncompleteTodos = todoList.todos.any((todo) => !todo.isCompleted);

    if (hasIncompleteTodos) {
      // Show confirmation dialog for lists with incomplete todos
      bool? shouldDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Warning'),
            content: Text(
                'This list contains incomplete todos. Are you sure you want to delete it?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );

      if (shouldDelete == true) {
        setState(() {
          todoLists.remove(todoList);
        });
        await _saveTodoLists();
      }
    } else {
      // If all todos are complete, delete without confirmation
      setState(() {
        todoLists.remove(todoList);
      });
      await _saveTodoLists();
    }
  }
}
