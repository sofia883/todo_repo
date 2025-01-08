import 'package:flutter/material.dart';
import 'todo_service.dart';
import 'dart:math';

// Update the TodoList widget to work with TodoListData
class TodoList extends StatefulWidget {
  final TodoListData? existingTodoList;
  final TodoListData? todoListData;

  const TodoList({this.todoListData, this.existingTodoList});

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
  late String currentCategory;
  late Color currentCategoryColor;
  bool showEmptyField = false;
  bool isCurrentLineEmpty = true;

  List<TodoItem> _deletedTodos = [];
  List<int> _deletedIndices = [];

  @override
  void initState() {
    super.initState();
    _newTodoFocus = FocusNode();
    todos = widget.existingTodoList?.todos ?? [];
    currentCategory = widget.todoListData?.category ?? 'Personal';
    currentCategoryColor =
        widget.todoListData?.categoryColor ?? Colors.pink[300]!;

    newTodoController.addListener(() {
      if (newTodoController.text.isNotEmpty) {
        setState(() {});
      }
    });
  }

  Widget _buildCategorySelector() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink[900],
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryChip('Personal', Colors.pink[300]!),
              _buildCategoryChip('Work', Colors.blue[300]!),
              _buildCategoryChip('Shopping', Colors.green[300]!),
              _buildCategoryChip('Health', Colors.purple[300]!),
              _buildCategoryChip('Travel', Colors.orange[300]!),
              _buildCategoryChip('Fitness', Colors.red[300]!),
              _buildCategoryChip('Education', Colors.yellow[300]!),
              _buildCategoryChip('Finance', Colors.teal[300]!),
              _buildCategoryChip('Entertainment', Colors.cyan[300]!),
              _buildCategoryChip('Others', Colors.grey[400]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, Color color) {
    final isSelected = currentCategory == category;
    return FilterChip(
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      backgroundColor: Colors.grey[100],
      label: Text(
        category,
        style: TextStyle(
          color: isSelected ? color.darker : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onSelected: (bool selected) {
        setState(() {
          currentCategory = category;
          currentCategoryColor = color;
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
    );
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
        backgroundColor: currentCategoryColor,
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
        backgroundColor: currentCategoryColor.withOpacity(0.2),
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
                category: currentCategory, // Use the current category
                categoryColor: currentCategoryColor, // Use the current color
                title: currentCategory,
                todos: todos,
              ),
            );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: currentCategoryColor.withOpacity(0.1),
        ),
        child: Column(
          children: [
            _buildCategorySelector(),
            Expanded(
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
                        _buildCompletionCounter(),
                        SizedBox(height: 20),
                        Expanded(
                          child: ListView.builder(
                            itemCount:
                                todos.length + (isCurrentLineEmpty ? 1 : 2),
                            itemBuilder: (context, index) {
                              if (index < todos.length) {
                                return buildTodoItem(index);
                              } else if (index == todos.length) {
                                return _buildNewTodoField(
                                    index, DateTime.now(), null);
                              } else if (index == todos.length + 1 &&
                                  !isCurrentLineEmpty) {
                                return _buildEmptyTodoField();
                              }
                              return SizedBox.shrink();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
              category: currentCategory, // Use the current category
              categoryColor: currentCategoryColor, // Use the current color
              title: currentCategory,
              todos: todos,
            ),
          );
        },
        backgroundColor: currentCategoryColor,
        child: Icon(Icons.check, color: Colors.white),
      ),
    );
  }

  Widget _buildCompletionCounter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: currentCategoryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: currentCategoryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        '${todos.where((todo) => todo.isCompleted).length}/${todos.length}',
        style: TextStyle(
          color: currentCategoryColor.darker,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
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

    // Generate or retrieve a persistent color for the todo
    todo.backgroundColor;

    double progress = todo.isCompleted ? 1.0 : 0.0;
    return StatefulBuilder(
      builder: (context, setState) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: currentCategoryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
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

                      // Recalculate progress when status changes
                      progress = todo.isCompleted
                          ? 1.0
                          : (DateTime.now()
                                      .difference(todo.createdAt)
                                      .inMinutes /
                                  1440)
                              .clamp(0.0, 1.0);

                      this.setState(() {});
                    });

                    final updatedList = TodoListData(
                      category: 'Personal', // Default category
                      categoryColor: Colors.pink[300]!, // Default color
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
                  // ... rest of the code remains the same

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
                                ? currentCategoryColor
                                : Colors.transparent,
                            border: todo.isCompleted
                                ? null
                                : Border.all(
                                    color:
                                        currentCategoryColor.withOpacity(0.5),
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
                                  ? currentCategoryColor
                                  : currentCategoryColor.darker,
                            ),
                            child: Text(todo.text),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            todo.isDetailsExpanded!
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: currentCategoryColor,
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
                            activeColor: currentCategoryColor,
                            inactiveColor:
                                currentCategoryColor.withOpacity(0.2),
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
                border:
                    Border.all(color: currentCategoryColor.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: currentCategoryColor,
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
                  hintStyle:
                      TextStyle(color: currentCategoryColor.withOpacity(0.5)),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(color: currentCategoryColor.darker),
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
              icon: Icon(Icons.add, color: currentCategoryColor),
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

  Future<void> _addNewTodo(String value) async {
    if (value.trim().isNotEmpty) {
      setState(() {
        todos.add(TodoItem(
          text: value.trim(),
          createdAt: DateTime.now(),
        ));
        newTodoController.clear();
        isCurrentLineEmpty = true;
      });

      var currentLists = await TodoStorage.loadTodoLists();
      currentLists.removeWhere((list) =>
          list.title == titleController.text ||
          (list.title.isEmpty && listHasSameTodos(list, todos)));

      currentLists.add(TodoListData(
        category: currentCategory, // Use the selected category
        categoryColor: currentCategoryColor, // Use the selected color
        title: titleController.text,
        todos: todos,
      ));

      await TodoStorage.saveTodoLists(currentLists);
    }
  }

  bool listHasSameTodos(TodoListData list1, List<TodoItem> todos) {
    if (list1.todos.length != todos.length) return false;
    for (int i = 0; i < todos.length; i++) {
      if (list1.todos[i].text != todos[i].text) return false;
    }
    return true;
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

extension ColorExtension on Color {
  Color get darker {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }
}
