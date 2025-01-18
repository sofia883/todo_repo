import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_app/data/todo_notification_service.dart';
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
  final NotificationService _notificationService = NotificationService();
  Timer? _timer;
  late List<TodoItem> todos;
  late DateTime selectedDate;
  late DateTime displayedMonth;
  late String currentCategory;
  late Color currentCategoryColor;
  bool showMyTasksOnly = false;
  bool isLoading = true;
  final ScrollController _calendarScrollController = ScrollController();
  final TextEditingController _quickAddController = TextEditingController();
  final TextEditingController _quickAddSubtaskController =
      TextEditingController();

  StreamSubscription? _todoSubscription; // Add this
  final TodoStorage _todoStorage = TodoStorage();
  List<TodoItem> _currentTasks = [];
  bool isQuickAddMode = false;
// Update the timer check method
  void _checkAndUpdateTasksStatus() async {
    final now = DateTime.now();
    bool needsUpdate = false;

    for (var todo in todos) {
      final dueDateTime = DateTime(
        todo.dueDate.year,
        todo.dueDate.month,
        todo.dueDate.day,
        todo.dueTime?.hour ?? 23,
        todo.dueTime?.minute ?? 59,
      );

      // Check if task just became overdue
      if (!todo.isCompleted && dueDateTime.isBefore(now) && !todo.isOverdue) {
        todo.isOverdue = true;
        needsUpdate = true;
        await _notificationService.scheduleTodoNotification(todo);
      }
    }

    // Only rebuild if needed
    if (needsUpdate && mounted) {
      setState(() {
        // This will trigger _buildTaskList to run again
        _currentTasks =
            showMyTasksOnly ? _getOverdueTasks() : _getTasksForSelectedDate();
      });
    }
  }

// Update the timer to check more frequently
  void _startOverdueTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        _checkAndUpdateTasksStatus();
      }
    });
  }

// Update your _getTasksForSelectedDate method
  List<TodoItem> _getTasksForSelectedDate() {
    final now = DateTime.now();

    return todos.where((todo) {
      final isSameDate = todo.dueDate.year == selectedDate.year &&
          todo.dueDate.month == selectedDate.month &&
          todo.dueDate.day == selectedDate.day;

      if (!isSameDate) return false;

      // For current date, filter out overdue tasks
      if (selectedDate.year == now.year &&
          selectedDate.month == now.month &&
          selectedDate.day == now.day) {
        final dueDateTime = DateTime(
          todo.dueDate.year,
          todo.dueDate.month,
          todo.dueDate.day,
          todo.dueTime?.hour ?? 23,
          todo.dueTime?.minute ?? 59,
        );
        return !dueDateTime.isBefore(now);
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    // _startOverdueTimer();
    selectedDate = DateTime.now();
    displayedMonth = DateTime.now();
    currentCategory = widget.todoListData?.category ?? 'Personal';
    currentCategoryColor = widget.todoListData?.categoryColor ?? Colors.indigo;
    todos = [];
    print('InitState called - loading todos');
    _loadTodos();
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddSubtaskController.dispose();
    _todoSubscription?.cancel(); // Cancel subscription when disposing
    _timer?.cancel();
    super.dispose();
  }

  List<TodoItem> _getOverdueTasks() {
    return todos.where((task) => _isTaskOverdue(task)).toList();
  }

  bool _isTaskOverdue(TodoItem todo) {
    if (todo.isCompleted) return false;

    final now = DateTime.now();
    final dueDateTime = DateTime(
      todo.dueDate.year,
      todo.dueDate.month,
      todo.dueDate.day,
      todo.dueTime?.hour ?? 23,
      todo.dueTime?.minute ?? 59,
    );

    return dueDateTime.isBefore(now);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showMonthYearDialog(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthYearDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int selectedYear = displayedMonth.year;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year selector
                    Row(
                      children: [
                        DropdownButton<int>(
                          value: selectedYear,
                          items: [
                            for (int year = DateTime.now().year;
                                year <= DateTime.now().year + 4;
                                year++)
                              DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year.toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (int? year) {
                            if (year != null) {
                              setState(() => selectedYear = year);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Months grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int month = 1; month <= 12; month++)
                          if (!(selectedYear == DateTime.now().year &&
                              month < DateTime.now().month))
                            InkWell(
                              onTap: () {
                                final newDate = DateTime(selectedYear, month);
                                Navigator.of(context).pop();
                                this.setState(() {
                                  displayedMonth = newDate;
                                  selectedDate = newDate;
                                });
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: month == displayedMonth.month &&
                                          selectedYear == displayedMonth.year
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: month == displayedMonth.month &&
                                            selectedYear == displayedMonth.year
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _getMonthName(month).substring(0, 3),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight:
                                          month == displayedMonth.month &&
                                                  selectedYear ==
                                                      displayedMonth.year
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                      color: month == displayedMonth.month &&
                                              selectedYear ==
                                                  displayedMonth.year
                                          ? Theme.of(context).primaryColor
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

// Helper method to get month name
  String _getMonthName(int month) {
    return DateFormat('MMMM').format(DateTime(2024, month));
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

  Widget _buildTaskItem(TodoItem todo, bool isOverdue) {
    // Helper function to check if all subtasks are complete
    bool areAllSubtasksComplete() {
      return todo.subtasks.every((subtask) => subtask.isCompleted);
    }

    // Helper function to update main task status based on subtasks
    void updateMainTaskStatus(StateSetter setState) {
      final allComplete = areAllSubtasksComplete();
      if (todo.isCompleted != allComplete) {
        setState(() {
          todo.isCompleted = allComplete;
          todo.completedAt = allComplete ? DateTime.now() : null;
        });
      }
    }

    Future<void> handleDelete(TodoItem todo) async {
      final deletedTodo = todo;

      try {
        await _todoStorage.deleteTodo(todo.id);

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                try {
                  setState(() {
                    todos.add(deletedTodo);
                  });

                  await _todoStorage.addTodo(deletedTodo);

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task restored'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  setState(() {
                    todos.remove(deletedTodo);
                  });

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to restore task'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        // If deletion fails, restore the item to UI
        setState(() {
          todos.add(deletedTodo);
        });

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete task'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Future<void> handleMainTaskStatusChange(
        bool? newValue, StateSetter setState) async {
      if (newValue == null) return;

      final shouldUpdate =
          await _showTaskCompletionDialog(todo, todo.isCompleted);
      if (!shouldUpdate) return;

      setState(() {
        todo.isCompleted = newValue;
        todo.completedAt = newValue ? DateTime.now() : null;

        // Update all subtasks' completion status based on the main task
        for (var subtask in todo.subtasks) {
          subtask.isCompleted = newValue;
          subtask.completedAt = newValue ? DateTime.now() : null;
        }
      });

      try {
        await _todoStorage.updateTodo(todo);

        // Show success snackbar
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? 'Main task and subtasks marked as complete'
                : 'Main task and subtasks marked as incomplete'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        setState(() {
          todo.isCompleted = !newValue;
          todo.completedAt = !newValue ? DateTime.now() : null;

          // Revert subtasks' completion status
          for (var subtask in todo.subtasks) {
            subtask.isCompleted = !newValue;
            subtask.completedAt = !newValue ? DateTime.now() : null;
          }
        });

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task and subtasks'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Dismissible(
          key: Key(todo.id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            final shouldDelete = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Task'),
                content:
                    const Text('Are you sure you want to delete this task?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('DELETE',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (shouldDelete ?? false) {
              handleDelete(todo);
            }
            return false;
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isOverdue
                      ? Colors.red.withOpacity(0.08)
                      : currentCategoryColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox with circular background
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOverdue
                              ? Colors.red.withOpacity(0.1)
                              : currentCategoryColor.withOpacity(0.1),
                        ),
                        child: Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: todo.isCompleted,
                            onChanged: (bool? newValue) =>
                                handleMainTaskStatusChange(newValue, setState),
                            activeColor:
                                isOverdue ? Colors.red : currentCategoryColor,
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Task content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              todo.title.isEmpty ? 'Untitled Task' : todo.title,
                              style: GoogleFonts.poppins(
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.isCompleted
                                    ? Colors.grey[400]
                                    : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            // Description if available
                            if (todo.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                todo.description,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            // Date and time
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color:
                                      isOverdue ? Colors.red : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  todo.dueTime != null
                                      ? DateFormat('MMM d, h:mm a')
                                          .format(DateTime(
                                          todo.dueDate.year,
                                          todo.dueDate.month,
                                          todo.dueDate.day,
                                          todo.dueTime!.hour,
                                          todo.dueTime!.minute,
                                        ))
                                      : DateFormat('MMM d')
                                          .format(todo.dueDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isOverdue
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Expand/collapse button if has subtasks
                      if (todo.subtasks.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              todo.isSubtasksExpanded =
                                  !todo.isSubtasksExpanded;
                            });
                          },
                          icon: AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: todo.isSubtasksExpanded ? 0.5 : 0,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: currentCategoryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Subtasks
                if (todo.isSubtasksExpanded && todo.subtasks.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 56, right: 16, bottom: 16),
                    child: Column(
                      children: todo.subtasks.map((subtask) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: subtask.isCompleted,
                                  onChanged: (bool? value) async {
                                    if (value == null) return;
                                    setState(() {
                                      subtask.isCompleted = value;
                                      subtask.completedAt =
                                          value ? DateTime.now() : null;
                                    });
                                    updateMainTaskStatus(setState);
                                    try {
                                      await _todoStorage.updateTodo(todo);
                                    } catch (e) {
                                      // Handle error
                                    }
                                  },
                                  activeColor: currentCategoryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  subtask.title,
                                  style: GoogleFonts.inter(
                                    decoration: subtask.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: subtask.isCompleted
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskTabs() {
    final upcomingTasks = _getTasksForSelectedDate();
    final overdueTasks = _getOverdueTasks();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildTab(
              'Upcoming (${upcomingTasks.length})',
              !showMyTasksOnly && !isQuickAddMode,
              () {
                setState(() {
                  showMyTasksOnly = false;
                  isQuickAddMode = false;
                });
              },
            ),
            const SizedBox(width: 12),
            _buildTab(
              'Overdue (${overdueTasks.length})',
              showMyTasksOnly && !isQuickAddMode,
              () {
                setState(() {
                  showMyTasksOnly = true;
                  isQuickAddMode = false;
                });
              },
            ),
            const SizedBox(width: 12),
            _buildTab(
              'Quick Add',
              isQuickAddMode,
              () {
                setState(() {
                  isQuickAddMode = !isQuickAddMode;
                  showMyTasksOnly = false;
                });
              },
              icon: Icons.add_circle_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    String text,
    bool isSelected,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? currentCategoryColor : Colors.grey[600],
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isSelected ? Colors.black87 : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

// Update the _buildTaskList method
  Widget _buildTaskList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Get and store current tasks
    _currentTasks =
        showMyTasksOnly ? _getOverdueTasks() : _getTasksForSelectedDate();

    if (_currentTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              showMyTasksOnly
                  ? 'No overdue tasks'
                  : 'No tasks for ${DateFormat('MMMM d').format(selectedDate)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(DateTime.now().millisecondsSinceEpoch), // Force rebuild
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _currentTasks.length,
      itemBuilder: (context, index) {
        final todo = _currentTasks[index];
        final isOverdue = _isTaskOverdue(todo);
        return _buildTaskItem(todo, isOverdue);
      },
    );
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

  QuickTask _convertQuickTaskToTodoItem(QuickTask quickTask) {
    return QuickTask(
      id: quickTask.id,
      title: quickTask.title,
      createdAt: quickTask.createdAt,
      subtasks: quickTask.subtasks,
      // Add any additional TodoItem fields with default values
      isCompleted: false,
      // Add other required fields based on your TodoItem class structure
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Add this conversion method to your class
    TodoItem _convertQuickTaskToTodoItem(QuickTask quickTask) {
      return TodoItem(
        id: quickTask.id,
        title: quickTask.title,
        description: '', // QuickTask doesn't have description
        createdAt: quickTask.createdAt,
        dueDate:
            DateTime.now().add(const Duration(days: 1)), // Default to tomorrow
        subtasks: quickTask.subtasks, // SubTask class is the same for both
        isCompleted: quickTask.isCompleted,
        completedAt: quickTask.completedAt,
        isQuickTask: true, // Mark as a quick task
      );
    }

    Widget mainContent;
    if (isQuickAddMode) {
      mainContent = QuickAddTaskSheet(
        onTaskAdded: (QuickTask quickTask) {
          setState(() {
            // Convert QuickTask to TodoItem before adding
            final todoItem = _convertQuickTaskToTodoItem(quickTask);
            todos.add(todoItem);
            isQuickAddMode = false;
          });
        },
      );
    } else {
      mainContent = _buildTaskList();
    }

    return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.account_circle,
              color: currentCategoryColor,
              size: 45,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(todos: todos),
                ),
              );
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthYearSelector(),
              _buildCalendar(),
              _buildTaskTabs(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: mainContent,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: isQuickAddMode
            ? FloatingActionButton(
                onPressed: () => setState(() => isQuickAddMode = true),
                backgroundColor: currentCategoryColor,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : FloatingActionButton(
                onPressed: _showAddTaskDialog, // Call the add task dialog
                backgroundColor: currentCategoryColor,
                child: const Icon(Icons.add_task, color: Colors.white),
              ));
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
            height: MediaQuery.of(context).size.height * 0.75,
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

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
}

class MonthYearSelector extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final DateTime initialDate;

  const MonthYearSelector({
    Key? key,
    required this.onDateSelected,
    required this.initialDate,
  }) : super(key: key);

  @override
  State<MonthYearSelector> createState() => _MonthYearSelectorState();
}

class _MonthYearSelectorState extends State<MonthYearSelector> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Dropdown
          DropdownButton<int>(
            value: selectedYear,
            isExpanded: true,
            items: List.generate(10, (index) {
              final year = DateTime.now().year + index;
              return DropdownMenuItem(
                value: year,
                child: Text(
                  year.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
            onChanged: (int? year) {
              if (year != null) {
                setState(() {
                  selectedYear = year;
                });
              }
            },
          ),

          const SizedBox(height: 16),

          // Months Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = month == selectedMonth &&
                  selectedYear == widget.initialDate.year;
              final isCurrentYear = selectedYear == DateTime.now().year;
              final isPastMonth = isCurrentYear && month < DateTime.now().month;

              return Material(
                color: isSelected
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: isPastMonth
                      ? null
                      : () {
                          setState(() {
                            selectedMonth = month;
                          });
                          widget.onDateSelected(DateTime(selectedYear, month));
                        },
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('MMM').format(DateTime(2024, month)),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isPastMonth
                            ? Colors.grey.withOpacity(0.5)
                            : isSelected
                                ? Colors.blue
                                : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class QuickAddTaskSheet extends StatefulWidget {
  final Function(QuickTask) onTaskAdded;

  const QuickAddTaskSheet({
    Key? key,
    required this.onTaskAdded,
  }) : super(key: key);

  @override
  _QuickAddTaskSheetState createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _subtaskControllers = [
    TextEditingController()
  ];
  final _formKey = GlobalKey<FormState>();

  void _addSubtaskField() {
    setState(() {
      _subtaskControllers.add(TextEditingController());
    });
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    // Create subtasks using SubTask instead of QuickSubTask
    final subtasks = _subtaskControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => SubTask(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: controller.text,
              isCompleted: false,
            ))
        .toList();

    final task = QuickTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      createdAt: DateTime.now(),
      subtasks: subtasks, // Now this matches the expected type List<SubTask>
    );

    widget.onTaskAdded(task);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Add Task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter a task title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subtaskControllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _subtaskControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Subtask ${index + 1}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (_subtaskControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeSubtaskField(index),
                          color: Colors.red,
                        ),
                    ],
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addSubtaskField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Subtask'),
                ),
                ElevatedButton(
                  onPressed: _saveTask,
                  child: const Text('Save Task'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _subtaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
