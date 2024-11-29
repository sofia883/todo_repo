import 'package:flutter/material.dart';
import 'todo_service.dart';

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
    _newTodoFocus = FocusNode();
    _scrollController.dispose();
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

  @override
  void dispose() {
    _newTodoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
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
                            return buildTodoItem(index);
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: 'Add Title',
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
          ),
        ),
        // Completion counter
        Container(
          margin: EdgeInsets.only(left: 8),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.pink[200]!,
              width: 1.5,
            ),
          ),
          child: Text(
            '${todos.where((todo) => todo.isCompleted).length}/${todos.length}',
            style: TextStyle(
              color: Colors.pink[400],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
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

    String day = '${dateTime.day}${_getDaySuffix(dateTime.day)}';
    String month = months[dateTime.month - 1];
    String time = dateTime.hour > 12
        ? '${dateTime.hour - 12}:${dateTime.minute.toString().padLeft(2, '0')}pm'
        : '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}am';

    return '$day $month at $time';
  }

  String _getDaySuffix(int day) {
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

  Widget buildTodoItem(int index) {
    final todo = todos[index];
    double progress = todo.isCompleted
        ? 1.0
        : (DateTime.now().difference(todo.createdAt).inMinutes / 1440)
            .clamp(0.0, 1.0);

    return StatefulBuilder(
      builder: (context, setState) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                InkWell(
                  onTap: () async {
                    setState(() {
                      todo.isCompleted = !todo.isCompleted;
                      todo.completedAt =
                          todo.isCompleted ? DateTime.now() : null;
                      this.setState(() {});
                    });

                    final updatedList = TodoListData(
                      title: titleController.text,
                      todos: todos,
                    );
                    await TodoStorage.saveTodoLists(
                        (await TodoStorage.loadTodoLists())
                          ..removeWhere((list) =>
                              widget.existingTodoList != null &&
                              list.title == widget.existingTodoList!.title)
                          ..add(updatedList));
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: todo.isCompleted
                                ? Colors.pink[400]
                                : Colors.transparent,
                            border: todo.isCompleted
                                ? null
                                : Border.all(
                                    color: Colors.pink[200]!,
                                    width: 1,
                                  ),
                          ),
                          child: todo.isCompleted
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Container(),
                        ),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.isCompleted
                                  ? Colors.pink[400]
                                  : Colors.pink[900],
                            ),
                            child: Text(todo.text),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            todo.isDetailsExpanded!
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: Colors.pink[400],
                          ),
                          onPressed: () {
                            setState(() {
                              todo.isDetailsExpanded = !todo.isDetailsExpanded!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (todo.isDetailsExpanded!)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatDateTime(todo.createdAt),
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                            ),
                            Spacer(),
                            Text(
                              todo.completedAt != null
                                  ? _formatDateTime(todo.completedAt!)
                                  : "Not completed",
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            thumbShape:
                                RoundSliderThumbShape(enabledThumbRadius: 10),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: progress,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (_) {},
                            activeColor: Colors.pink[400],
                            inactiveColor: Colors.pink[100],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.pink[400]),
                              onPressed: () =>
                                  _showDeleteConfirmation(context, index),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

  Future<void> _addNewTodo(String value) async {
    if (value.trim().isNotEmpty) {
      setState(() {
        // Add the new to-do item
        todos.add(TodoItem(
          text: value.trim(),
          createdAt: DateTime.now(),
        ));
        newTodoController.clear(); // Clear the text field
        isCurrentLineEmpty = true; // Reset the empty state
      });
      _newTodoFocus.unfocus(); // Unfocus the current input
      _newTodoFocus = FocusNode(); // Create a new focus node for the next input
      _newTodoFocus.requestFocus(); // Set focus to the next input
      // Save the updated list to storage
      final updatedList = TodoListData(
        title: titleController.text,
        todos: todos,
      );
      await TodoStorage.saveTodoLists((await TodoStorage.loadTodoLists())
        ..removeWhere((list) =>
            widget.existingTodoList != null &&
            list.title == widget.existingTodoList!.title)
        ..add(updatedList));

      // Scroll to the newly added task and focus on the input field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Scroll to the bottom
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

        // Focus on the text field for a new task
        if (!_newTodoFocus.hasFocus) {
          _newTodoFocus.requestFocus();
        }
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
