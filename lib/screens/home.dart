import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:to_do_app/screens/profile_page.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:uuid/uuid.dart';

class TodoList extends StatefulWidget {
  final TodoListData? existingTodoList;
  final TodoListData? todoListData;

  const TodoList({this.todoListData, this.existingTodoList});

  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late List<TodoItem> todos;
  late DateTime selectedDate;
  late DateTime displayedMonth;
  late String currentCategory;
  late Color currentCategoryColor;
  bool showMyTasksOnly = false;
  bool isLoading = true;
  final ScrollController _calendarScrollController = ScrollController();
  StreamSubscription? _todoSubscription; // Add this
  final TodoStorage _todoStorage = TodoStorage();
  // Helper method to create DateTime with time
  List<TodoItem> _getTasksForSelectedDate() {
    return todos.where((task) {
      final isSameDate = task.dueDate.year == selectedDate.year &&
          task.dueDate.month == selectedDate.month &&
          task.dueDate.day == selectedDate.day;
      return isSameDate && !_isTaskOverdue(task);
    }).toList();
  }

  List<TodoItem> _getOverdueTasks() {
    return todos.where((task) => _isTaskOverdue(task)).toList();
  }

  bool _isTaskOverdue(TodoItem task) {
    if (task.isCompleted) return false; // Completed tasks are not overdue.
    final now = DateTime.now();
    final taskDueDateTime = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      task.dueTime?.hour ?? 23,
      task.dueTime?.minute ?? 59,
    );
    return taskDueDateTime.isBefore(now);
  }

  DateTime _createDateTime(DateTime date, TimeOfDay? time) {
    return time != null
        ? DateTime(date.year, date.month, date.day, time.hour, time.minute)
        : DateTime(date.year, date.month, date.day, 23, 59);
  }

// Check if date has any non-completed, non-overdue tasks
  bool _hasTasksOnDate(DateTime date) {
    final now = DateTime.now();
    return todos.any((todo) {
      // Skip completed tasks
      if (todo.isCompleted) return false;

      // Check if the dates match
      final isMatchingDate = todo.dueDate.year == date.year &&
          todo.dueDate.month == date.month &&
          todo.dueDate.day == date.day;

      // Convert todo date and time to DateTime for comparison
      final todoDateTime = _createDateTime(todo.dueDate, todo.dueTime);

      // Return true if matching date and not overdue
      return isMatchingDate && todoDateTime.isAfter(now);
    });
  }

  Widget _buildMonthYearSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PopupMenuButton<DateTime>(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_getMonthName(displayedMonth.month)} ${displayedMonth.year}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        onSelected: (DateTime date) {
          setState(() {
            displayedMonth = date;
            selectedDate = date;
          });
        },
        itemBuilder: (BuildContext context) {
          final currentYear = DateTime.now().year;
          List<PopupMenuItem<DateTime>> items = [];

          // Generate items for next 2 years
          for (int year = currentYear; year <= currentYear + 1; year++) {
            for (int month = 1; month <= 12; month++) {
              // Skip past months for current year
              if (year == currentYear && month < DateTime.now().month) continue;

              final date = DateTime(year, month);
              items.add(
                PopupMenuItem<DateTime>(
                  value: date,
                  child: Text(
                    '${_getMonthName(month)} $year',
                    style: GoogleFonts.inter(),
                  ),
                ),
              );
            }
          }
          return items;
        },
      ),
    );
  }

  Future<bool> _showTaskCompletionDialog(
      TodoItem todo, bool isCurrentlyCompleted) async {
    String dialogTitle =
        isCurrentlyCompleted ? 'Mark Task as Incomplete?' : 'Complete Task?';
    String dialogContent = isCurrentlyCompleted
        ? 'Are you sure you want to mark this task as incomplete?'
        : 'Are you sure you want to mark this task as complete?';
    String actionButtonText =
        isCurrentlyCompleted ? 'Mark Incomplete' : 'Complete';

    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            dialogTitle,
            style: GoogleFonts.aBeeZee(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContent,
                style: GoogleFonts.aBeeZee(),
              ),
              SizedBox(height: 12),
              Text(todo.title, style: GoogleFonts.aBeeZee()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.aBeeZee(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentCategoryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionButtonText,
                style: GoogleFonts.aBeeZee(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _buildTaskTabs() {
    final upcomingTasks = _getTasksForSelectedDate();
    final overdueTasks = _getOverdueTasks();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTab(
            'Upcoming tasks (${upcomingTasks.length})',
            !showMyTasksOnly,
            () {
              setState(() => showMyTasksOnly = false);
            },
            fontSize: 13.0,
          ),
          SizedBox(width: 16),
          _buildTab(
            'Overdue tasks (${overdueTasks.length})',
            showMyTasksOnly,
            () {
              setState(() => showMyTasksOnly = true);
            },
            fontSize: 13.0,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    String text,
    bool isSelected,
    VoidCallback onTap, {
    double fontSize = 20,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: fontSize,
                color: isSelected ? Colors.black87 : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.2,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: currentCategoryColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: currentCategoryColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${todos.length}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    displayedMonth = DateTime.now();
    currentCategory = widget.todoListData?.category ?? 'Personal';
    currentCategoryColor = widget.todoListData?.categoryColor ?? Colors.indigo;
    todos = [];
    print('InitState called - loading todos');
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    try {
      if (todos.isEmpty) {
        setState(() {
          isLoading = true;
        });
      }

      await _todoSubscription?.cancel();

      _todoSubscription = _todoStorage.getTodosStream().listen(
        (updatedTodos) {
          print('Received ${updatedTodos.length} todos from stream');
          setState(() {
            todos = updatedTodos;
            isLoading = false;
          });
        },
        onError: (error) {
          print('Error loading todos: $error');
          setState(() {
            isLoading = false;
          });
        },
      );
    } catch (e) {
      print('Error setting up todos stream: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildTaskList() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(currentCategoryColor),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading your tasks...',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Modified filtering logic
    List<TodoItem> tasksToShow;
    if (showMyTasksOnly) {
      // Only show overdue tasks when specifically filtered
      tasksToShow = _getOverdueTasks();
    } else {
      // Show all tasks for selected date, including completed ones
      tasksToShow = _getTasksForSelectedDate();
    }

    if (tasksToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              showMyTasksOnly
                  ? 'No overdue tasks'
                  : 'No tasks for ${_getMonthName(selectedDate.month)} ${selectedDate.day}',
              style: GoogleFonts.beVietnamPro(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      );
    }

    // Sort tasks: incomplete tasks first, then completed tasks
    final sortedTasks = [...tasksToShow]..sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;

        // Sort by due time for tasks with the same completion status.
        if (a.dueTime != null && b.dueTime != null) {
          return (a.dueTime!.hour * 60 + a.dueTime!.minute)
              .compareTo(b.dueTime!.hour * 60 + b.dueTime!.minute);
        }
        return 0;
      });

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final todo = sortedTasks[index];
        final isOverdue = _isTaskOverdue(todo);

        return Container(
          key: UniqueKey(),
          margin: EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey(todo.id),
            direction: DismissDirection.endToStart,
            // Rest of the Dismissible widget code remains the same
            child: _buildTaskItem(todo, isOverdue),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(TodoItem todo, bool isOverdue) {
    // Helper function to check and update main task status based on subtasks

    return Container(
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isOverdue
                ? Colors.red.withOpacity(0.08)
                : currentCategoryColor.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOverdue
                    ? Colors.red[100]
                    : currentCategoryColor.withOpacity(0.1),
              ),
              child: Checkbox(
                value: todo.isCompleted,
                onChanged: (bool? value) async {
                  if (value != null) {
                    final shouldUpdateStatus =
                        await _showTaskCompletionDialog(todo, todo.isCompleted);
                    if (shouldUpdateStatus) {
                      bool previousState = todo.isCompleted;
                      setState(() {
                        todo.isCompleted = value;
                        todo.completedAt = value ? DateTime.now() : null;

                        // Automatically mark all subtasks as completed if the main task is completed
                        if (value) {
                          for (var subtask in todo.subtasks) {
                            subtask.isCompleted = true;
                            subtask.completedAt = DateTime.now();
                          }
                        } else {
                          // Optionally, unmark all subtasks if the main task is unmarked
                          for (var subtask in todo.subtasks) {
                            subtask.isCompleted = false;
                            subtask.completedAt = null;
                          }
                        }
                      });

                      try {
                        await _todoStorage.updateTodoStatus(todo.id, value);
                        // Save the updated subtasks
                        await _todoStorage.updateTodo(todo);
                      } catch (e) {
                        setState(() {
                          todo.isCompleted = previousState;
                          todo.completedAt =
                              previousState ? DateTime.now() : null;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update task status'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                activeColor: isOverdue ? Colors.red : currentCategoryColor,
              ),
            ),
            title: Text(
              todo.title.isEmpty ? 'Untitled Task' : todo.title,
              style: GoogleFonts.poppins(
                decoration:
                    todo.isCompleted ? TextDecoration.lineThrough : null,
                color: todo.isCompleted ? Colors.grey[400] : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            subtitle: todo.description.isNotEmpty
                ? Text(
                    todo.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (todo.dueTime != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.red.withOpacity(0.1)
                          : currentCategoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isOverdue ? Colors.red : currentCategoryColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          todo.dueTime!.format(context),
                          style: GoogleFonts.inter(
                            color:
                                isOverdue ? Colors.red : currentCategoryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isOverdue)
                  TextButton(
                    onPressed: () => _showRescheduleDialog(context, todo),
                    child: Text(
                      'Reschedule',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildSubtaskList(todo), // Pass the function to subtask list
        ],
      ),
    );
  }

// Add this widget to show subtasks in the task item
  Widget _buildSubtaskList(TodoItem todo) {
    // Helper function to check and update main task status
    void checkAndUpdateMainTask() {
      if (todo.subtasks.isNotEmpty &&
          todo.subtasks.every((st) => st.isCompleted)) {
        setState(() {
          todo.isCompleted = true;
          todo.completedAt = DateTime.now();
        });
        _todoStorage.updateTodoStatus(todo.id, true);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todo.subtasks.isNotEmpty) ...[
          Divider(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Subtasks (${todo.subtasks.where((st) => st.isCompleted).length}/${todo.subtasks.length})',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          ...todo.subtasks.map((subtask) =>
              _buildSubtaskItem(todo, subtask, checkAndUpdateMainTask)),
        ],
        // Add subtask button
        TextButton.icon(
          icon: Icon(Icons.add, size: 18),
          label: Text('Add Subtask', style: GoogleFonts.inter()),
          onPressed: () => _showAddSubtaskDialog(todo),
          style: TextButton.styleFrom(
            foregroundColor: currentCategoryColor,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

// Add this widget to show individual subtask items
  Widget _buildSubtaskItem(
      TodoItem todo, SubTask subtask, VoidCallback onStatusChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 32), // Indent subtasks
          Checkbox(
            value: subtask.isCompleted,
            onChanged: (bool? value) async {
              if (value != null) {
                setState(() {
                  subtask.isCompleted = value;
                  subtask.completedAt = value ? DateTime.now() : null;
                });

                // Check if all subtasks are completed and update main task
                onStatusChanged();

                try {
                  await _todoStorage.updateTodo(todo);
                } catch (e) {
                  // Revert the change if update fails
                  setState(() {
                    subtask.isCompleted = !value;
                    subtask.completedAt = !value ? DateTime.now() : null;
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update subtask status'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            activeColor: currentCategoryColor,
          ),
          Expanded(
            child: Text(
              subtask.title,
              style: GoogleFonts.inter(
                decoration:
                    subtask.isCompleted ? TextDecoration.lineThrough : null,
                color: subtask.isCompleted ? Colors.grey[400] : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              setState(() {
                todo.subtasks.remove(subtask);
              });
              try {
                await _todoStorage.updateTodo(todo);
              } catch (e) {
                // Revert the change if update fails
                setState(() {
                  todo.subtasks.add(subtask);
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete subtask'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              // Check if removing this subtask affects the main task status
              onStatusChanged();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _todoSubscription?.cancel(); // Cancel subscription when disposing
    super.dispose();
  }

  Future<void> _showRescheduleDialog(
      BuildContext context, TodoItem todo) async {
    DateTime selectedDate = todo.dueDate;
    TimeOfDay? selectedTime = todo.dueTime;

    // Get current date and time
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Ensure initialDate is not before today
    if (selectedDate.isBefore(today)) {
      selectedDate = today;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reschedule Task',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        todo.title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 24),
                      ListTile(
                        leading: Icon(Icons.calendar_today),
                        title: Text(
                          'Due Date',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: today,
                            lastDate: DateTime.now().add(Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme:
                                      Theme.of(context).colorScheme.copyWith(
                                            primary: currentCategoryColor,
                                          ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.access_time),
                        title: Text(
                          'Due Time',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          selectedTime?.format(context) ?? 'No time set',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() => selectedTime = picked);
                          }
                        },
                      ),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Convert selected time to DateTime for comparison
                                final now = DateTime.now();
                                final selectedDateTime = selectedTime != null
                                    ? DateTime(
                                        selectedDate.year,
                                        selectedDate.month,
                                        selectedDate.day,
                                        selectedTime!.hour,
                                        selectedTime!.minute,
                                      )
                                    : selectedDate;

                                // Check if selected datetime is in the future
                                if (selectedDateTime.isBefore(now)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Please select a future date and time',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  // Update both date and time
                                  await _todoStorage.updateTodoDate(
                                    todo.id,
                                    selectedDate,
                                    selectedTime,
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Task rescheduled successfully',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to reschedule task',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Reschedule',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentCategoryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar() {
    final today = DateTime.now();
    final daysInMonth = _getDaysInMonth(displayedMonth);

    List<DateTime> orderedDates = [];

    for (int i = (displayedMonth.year == today.year &&
                displayedMonth.month == today.month)
            ? today.day
            : 1;
        i <= daysInMonth;
        i++) {
      orderedDates.add(DateTime(displayedMonth.year, displayedMonth.month, i));
    }

    if (orderedDates.length < 30) {
      final nextMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
      final daysToAdd = 31 - orderedDates.length;

      for (int i = 1; i <= daysToAdd; i++) {
        orderedDates.add(DateTime(nextMonth.year, nextMonth.month, i));
      }
    }

    orderedDates = orderedDates.take(31).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 100,
          child: ListView.builder(
            controller: _calendarScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: orderedDates.length,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final date = orderedDates[index];
              final isSelected = selectedDate.year == date.year &&
                  selectedDate.month == date.month &&
                  selectedDate.day == date.day;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isNextMonth = date.month != displayedMonth.month;

              return GestureDetector(
                onTap: () => setState(() => selectedDate = date),
                child: Container(
                  width: 60,
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? currentCategoryColor
                        : isToday
                            ? currentCategoryColor.withOpacity(0.1)
                            : isNextMonth
                                ? Colors.grey[100]
                                : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: currentCategoryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        )
                      else if (isToday)
                        BoxShadow(
                          color: currentCategoryColor.withOpacity(0.15),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ][date.weekday - 1],
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : isNextMonth
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${date.day}',
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? currentCategoryColor
                                  : isNextMonth
                                      ? Colors.grey[400]
                                      : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      if (_hasTasksOnDate(date)) ...[
                        SizedBox(height: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : currentCategoryColor,
                            boxShadow: [
                              BoxShadow(
                                color: (isSelected
                                        ? Colors.black
                                        : currentCategoryColor)
                                    .withOpacity(0.1),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.account_circle, color: currentCategoryColor, size: 45),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ProfilePage(todos: todos)),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonthYearSelector(),
            _buildCalendar(),
            _buildTaskTabs(),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: _buildTaskList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(),
        backgroundColor: currentCategoryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddTaskDialog() {
    final TextEditingController titleController = TextEditingController();
    final List<TextEditingController> subtaskControllers = [
      TextEditingController()
    ];
    bool showTitleError = false; // Add this state variable
    DateTime selectedDueDate = DateTime.now();
    TimeOfDay? selectedDueTime;
    String selectedDateType = 'today';
    bool showTimeError = false;

    // Predefined titles
    final List<String> predefinedTitles = [
      'Daily Meeting',
      'Weekly Review',
      'Doctor Appointment',
      'Gym Session',
      'Shopping',
      'Study',
      'Project Work'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isValidDueTime(DateTime date, TimeOfDay time) {
            final now = DateTime.now();
            final selectedDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            return selectedDateTime.isAfter(now);
          }

          void addNewSubtask() {
            setState(() {
              subtaskControllers.add(TextEditingController());
            });
          }

          void removeSubtask(int index) {
            setState(() {
              subtaskControllers[index].dispose();
              subtaskControllers.removeAt(index);
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Add Task',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Title Field with Dropdown
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: titleController,
                                style: GoogleFonts.inter(),
                                onChanged: (value) {
                                  // Clear error when user starts typing
                                  if (showTitleError) {
                                    setState(() {
                                      showTitleError = false;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Task Title',
                                  labelStyle: GoogleFonts.inter(
                                    color: showTitleError
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                  hintText: 'Enter task title',
                                  hintStyle: GoogleFonts.inter(
                                    color: Colors.grey[400],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: showTitleError
                                          ? Colors.red
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: showTitleError
                                          ? Colors.red
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: showTitleError
                                          ? Colors.red
                                          : currentCategoryColor,
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.task_alt,
                                    color: showTitleError ? Colors.red : null,
                                  ),
                                  errorText: showTitleError
                                      ? 'Please fill out this field'
                                      : null,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: PopupMenuButton<String>(
                                icon: Icon(Icons.arrow_drop_down),
                                onSelected: (String value) {
                                  titleController.text = value;
                                },
                                itemBuilder: (BuildContext context) {
                                  return predefinedTitles.map((String title) {
                                    return PopupMenuItem<String>(
                                      value: title,
                                      child: Text(
                                        title,
                                        style: GoogleFonts.inter(),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),

                        // Subtasks Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtasks',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline),
                                  color: currentCategoryColor,
                                  onPressed: addNewSubtask,
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            ...List.generate(
                              subtaskControllers.length,
                              (index) => Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: subtaskControllers[index],
                                        style: GoogleFonts.inter(),
                                        decoration: InputDecoration(
                                          hintText: 'Enter subtask',
                                          hintStyle: GoogleFonts.inter(
                                            color: Colors.grey[400],
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          prefixIcon: Icon(
                                              Icons.subdirectory_arrow_right),
                                        ),
                                      ),
                                    ),
                                    if (subtaskControllers.length > 1)
                                      IconButton(
                                        icon: Icon(Icons.remove_circle_outline),
                                        color: Colors.red[400],
                                        onPressed: () => removeSubtask(index),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Due Date',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 100,
                                      child: _buildDateOption(
                                        'Today',
                                        selectedDateType == 'today',
                                        () => setState(() {
                                          selectedDateType = 'today';
                                          selectedDueDate = DateTime.now();
                                          if (selectedDueTime != null &&
                                              !isValidDueTime(selectedDueDate,
                                                  selectedDueTime!)) {
                                            selectedDueTime = null;
                                          }
                                        }),
                                      ),
                                    ),
                                    Container(
                                      width: 100,
                                      child: _buildDateOption(
                                        'Tomorrow',
                                        selectedDateType == 'tomorrow',
                                        () => setState(() {
                                          selectedDateType = 'tomorrow';
                                          selectedDueDate = DateTime.now()
                                              .add(Duration(days: 1));
                                        }),
                                      ),
                                    ),
                                    Container(
                                      width: 100,
                                      child: InkWell(
                                        onTap: () async {
                                          final now = DateTime.now();
                                          final currentDate = DateTime(
                                              now.year, now.month, now.day);

                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: selectedDueDate
                                                    .isBefore(currentDate)
                                                ? currentDate
                                                : selectedDueDate,
                                            firstDate: currentDate,
                                            lastDate: DateTime(
                                                currentDate.year + 2, 12, 31),
                                            builder: (context, child) {
                                              return Theme(
                                                data:
                                                    Theme.of(context).copyWith(
                                                  colorScheme: Theme.of(context)
                                                      .colorScheme
                                                      .copyWith(
                                                        primary:
                                                            currentCategoryColor,
                                                      ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );

                                          if (picked != null) {
                                            setState(() {
                                              selectedDateType = 'custom';
                                              selectedDueDate = picked;
                                              if (selectedDueTime != null &&
                                                  !isValidDueTime(picked,
                                                      selectedDueTime!)) {
                                                selectedDueTime = null;
                                              }
                                            });
                                          }
                                        },
                                        child: Container(
                                          margin: EdgeInsets.all(8),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            color: selectedDateType == 'custom'
                                                ? currentCategoryColor
                                                : Colors.transparent,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color:
                                                    selectedDateType == 'custom'
                                                        ? Colors.white
                                                        : Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Pick',
                                                style: GoogleFonts.inter(
                                                  color: selectedDateType ==
                                                          'custom'
                                                      ? Colors.white
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 20, color: currentCategoryColor),
                                    SizedBox(width: 8),
                                    Text(
                                      '${selectedDueDate.day}/${selectedDueDate.month}/${selectedDueDate.year}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: currentCategoryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Time Selection
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: showTimeError
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.access_time,
                                  color: showTimeError ? Colors.red : null,
                                ),
                                title: Text(
                                  selectedDueTime != null
                                      ? '${selectedDueTime!.format(context)}'
                                      : 'Set time (Optional)',
                                  style: GoogleFonts.inter(
                                    color: showTimeError ? Colors.red : null,
                                  ),
                                ),
                                trailing: selectedDueTime != null
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () => setState(() {
                                          selectedDueTime = null;
                                          showTimeError = false;
                                        }),
                                      )
                                    : null,
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );

                                  if (picked != null) {
                                    if (isValidDueTime(
                                        selectedDueDate, picked)) {
                                      setState(() {
                                        selectedDueTime = picked;
                                        showTimeError = false;
                                      });
                                    } else {
                                      setState(() {
                                        selectedDueTime = null;
                                        showTimeError = true;
                                      });
                                    }
                                  }
                                },
                              ),
                              if (showTimeError)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: 16, right: 16, bottom: 8),
                                  child: Text(
                                    'Cannot set due time in the past',
                                    style: GoogleFonts.inter(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty) {
                              setState(() {
                                showTitleError = true;
                              });
                              return;
                            }

                            final uuid = Uuid();

                            // Create subtasks list
                            List<SubTask> subtasks = subtaskControllers
                                .where((controller) =>
                                    controller.text.trim().isNotEmpty)
                                .map((controller) => SubTask(
                                      id: uuid.v4(),
                                      title: controller.text.trim(),
                                    ))
                                .toList();

                            final newTodo = TodoItem(
                              id: uuid.v4(),
                              title: titleController.text.trim(),
                              description:
                                  "", // Empty as we're using subtasks instead
                              createdAt: DateTime.now(),
                              dueDate: selectedDueDate,
                              dueTime: selectedDueTime,
                              subtasks: subtasks,
                            );

                            try {
                              // Show loading indicator
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        currentCategoryColor),
                                  ),
                                ),
                              );

                              await _todoStorage.addTodo(newTodo);

                              // Close loading indicator
                              Navigator.of(context).pop();
                              // Close add task dialog
                              Navigator.of(context).pop();

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Task added successfully',
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              // Close loading indicator
                              Navigator.of(context).pop();

                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to add task. Please try again.',
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Add Task',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentCategoryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

// Update the date option builder for fixed width
  Widget _buildDateOption(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.all(8),
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? currentCategoryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? currentCategoryColor : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return monthNames[month - 1];
  }

  void _showAddSubtaskDialog(TodoItem todo) {
    final TextEditingController subtaskController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Subtask', style: GoogleFonts.poppins()),
        content: TextField(
          controller: subtaskController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter subtask',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.inter()),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Add', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentCategoryColor,
            ),
            onPressed: () async {
              if (subtaskController.text.trim().isNotEmpty) {
                final newSubtask = SubTask(
                  id: const Uuid().v4(),
                  title: subtaskController.text.trim(),
                );

                todo.subtasks.add(newSubtask);
                await _todoStorage.updateTodo(todo);
                setState(() {});
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
}
