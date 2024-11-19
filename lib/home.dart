import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TodoListData> todoLists = [];
  late TextEditingController titleController;
  bool isTitleEditing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Todo Lists'),
        backgroundColor: Colors.pink[100],
        elevation: 0,
      ),
      body: GridView.builder(
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
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TodoList()),
        ).then((result) {
          if (result != null && result.todos.isNotEmpty) {
            setState(() {
              todoLists.add(result);
            });
          }
        });
      },
      child: Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  } // Update the grid card preview in HomePage

  Widget _buildTodoCard(TodoListData todoList) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TodoList(existingTodoList: todoList),
          ),
        );
        if (result != null) {
          setState(() {
            int index = todoLists.indexOf(todoList);
            todoLists[index] = result;
          });
        }
      },
      onLongPress: () async {
        // Show options to delete or mark as completed
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Choose an option'),
              actions: <Widget>[
                // Option to delete the Todo list
                TextButton(
                  onPressed: () {
                    setState(() {
                      todoLists.remove(todoList);
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Delete'),
                ),
                // Option to mark all todos as completed
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var todo in todoList.todos) {
                        todo.isCompleted = true;
                      }
                    });
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
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todoList.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[300],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
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
                              width: 16,
                              height: 16,
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
                                      size: 12, color: Colors.white)
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
                    } else if (todoList.todos.length > 2) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            '• • •',
                            style: TextStyle(
                              color: Colors.pink[300],
                              fontSize: 20,
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
}

class TodoListData {
  String title;
  List<TodoItem> todos;

  TodoListData({
    required this.title,
    required this.todos,
  });
}

class TodoItem {
  String text;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;

  TodoItem({
    required this.text,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();
}

// Update the TodoList widget to work with TodoListData
class TodoList extends StatefulWidget {
  final TodoListData? existingTodoList;

  TodoList({this.existingTodoList});

  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late TextEditingController titleController;
  late List<TodoItem> todos;
  bool isTitleEditing = true;
  FocusNode _newTodoFocus = FocusNode();
  TextEditingController newTodoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool showEmptyField = false;
  bool isCurrentLineEmpty = true;

  List<TodoItem> _deletedTodos = [];
  List<int> _deletedIndices = [];
  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(
      text: widget.existingTodoList?.title ?? '',
    );
    todos = widget.existingTodoList?.todos ?? [];
    isTitleEditing = widget.existingTodoList == null;

    // Listen to new todo input
    newTodoController.addListener(() {
      if (newTodoController.text.isNotEmpty) {
        setState(() {}); // Refresh to show new line
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, int index) {
    // Store the deleted item and its index for potential undo
    final deletedTodo = todos[index];

    setState(() {
      todos.removeAt(index);
      _deletedTodos.add(deletedTodo);
      _deletedIndices.add(index);
    });

    ScaffoldMessenger.of(context)
        .clearSnackBars(); // Clear any existing snackbars
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(10),
        content: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 10),
            Text('Task deleted'),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.pink[100],
          onPressed: () {
            setState(() {
              // Get the last deleted item
              if (_deletedTodos.isNotEmpty) {
                final todoToRestore = _deletedTodos.removeLast();
                final indexToRestore = _deletedIndices.removeLast();
                // Insert at original position if possible
                if (indexToRestore <= todos.length) {
                  todos.insert(indexToRestore, todoToRestore);
                } else {
                  todos.add(todoToRestore);
                }
              }
            });
          },
        ),
        backgroundColor: Colors.pink[300],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (newTodoController.text.trim().isNotEmpty) {
            _addNewTodo(newTodoController.text);
          }

          Navigator.pop(
            context,
            TodoListData(
              title: titleController.text,
              todos: todos,
            ),
          );
        },
        backgroundColor: Colors.pink[300],
        child: Icon(Icons.fork_right, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFFFCE4EC),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            color: const Color.fromARGB(255, 249, 245, 247),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTitle(),
                  SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                        itemCount: todos.length + (isCurrentLineEmpty ? 1 : 2),
                        itemBuilder: (context, index) {
                          if (index < todos.length) {
                            // Display existing todo items
                            final todo = todos[index];
                            return _buildTodoItem(index);
                          } else if (index == todos.length) {
                            // Pass the index and provide default DateTime values for createdTime and completedTime
                            return _buildNewTodoField(
                                index, DateTime.now(), null);
                          } else if (index == todos.length + 1 &&
                              !isCurrentLineEmpty) {
                            // Pass the index when calling _buildEmptyTodoField
                            return _buildEmptyTodoField();
                          }
                          return SizedBox.shrink(); // Return an empty widget
                        }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return TextField(
      controller: titleController,
      decoration: InputDecoration(
        hintText: 'Untitled',
        border: InputBorder.none,
        hintStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.pink[300]!.withOpacity(0.5),
        ),
      ),
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.pink[900],
      ),
      onTap: () {
        if (!isTitleEditing) {
          setState(() {
            isTitleEditing = true;
            titleController.clear();
          });
        }
      },
    );
  }

  Widget _buildTodoItem(int index) {
    final todo = todos[index];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            todo.isCompleted = !todo.isCompleted;
            todo.completedAt = todo.isCompleted ? DateTime.now() : null;
          });
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: todo.isCompleted
                        ? Colors.pink[400]!
                        : Colors.pink[200]!,
                  ),
                  color:
                      todo.isCompleted ? Colors.pink[400] : Colors.transparent,
                ),
                child: Center(
                  child: todo.isCompleted
                      ? Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.pink[300],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              Expanded(
                child: Text(
                  todo.text,
                  style: TextStyle(
                    decoration:
                        todo.isCompleted ? TextDecoration.lineThrough : null,
                    color:
                        todo.isCompleted ? Colors.pink[400] : Colors.pink[900],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.pink[300]),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () => _showDeleteConfirmation(context, index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewTodoField(
      int index, DateTime createdTime, DateTime? completedTime) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pink[200]!),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.pink[300],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: newTodoController,
                focusNode: _newTodoFocus,
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Add new task",
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {
                    isCurrentLineEmpty = value.isEmpty;
                  });
                },
                onTap: () {
                  _newTodoFocus.requestFocus();
                },
                onSubmitted: (value) {
                  _addNewTodo(value);
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: Colors.pink[300]),
              onPressed: () {
                if (newTodoController.text.trim().isNotEmpty) {
                  _addNewTodo(newTodoController.text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

// Helper methods to format the date and time
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}${_getDayOfMonthSuffix(dateTime.day)} ${_getMonth(dateTime.month)} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _getDayOfMonthSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  void _addNewTodo(String value) {
    if (value.trim().isNotEmpty) {
      setState(() {
        todos.add(TodoItem(text: value.trim()));
        newTodoController.clear();
        isCurrentLineEmpty = true;

        // Move focus to the next line by adding a new controller for the next input
        _newTodoFocus.unfocus(); // Unfocus the current input
        _newTodoFocus =
            FocusNode(); // Create a new focus node for the next input
        _newTodoFocus.requestFocus(); // Set focus to the next input

        // Scroll to the bottom to show the new task
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
  }

  Widget _buildEmptyTodoField() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (newTodoController.text.trim().isNotEmpty) {
            _addNewTodo(newTodoController.text);
          }
          _newTodoFocus.requestFocus();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.pink[200]!),
                ),
                child: Center(
                  child: Text(
                    '${todos.length + 2}',
                    style: TextStyle(
                      color: Colors.pink[300],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 40, // Increased height for better tap target
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.pink[100]!, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
