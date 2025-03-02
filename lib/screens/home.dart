import 'package:to_do_app/common_imports.dart';
import 'package:to_do_app/widgets/date_time_picker.dart';

class HomePage extends StatefulWidget {
  final TodoListData? existingTodoList;
  final TodoListData? todoListData;

  const HomePage({this.todoListData, this.existingTodoList});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  late List<ScheduleTask> todos;
  late DateTime selectedDate;
  late DateTime displayedMonth;
  late String currentCategory;
  late Color currentCategoryColor;
  bool showMyTasksOnly = false;
  bool isLoading = true;
  bool isDarkMode = false;
  final ScrollController _calendarScrollController = ScrollController();
  final TextEditingController _quickAddController = TextEditingController();
  final TextEditingController _quickAddSubtaskController =
      TextEditingController();
  List<DailyTask> _quickTasks = [];
  StreamSubscription? _todoSubscription; // Add this

  List<ScheduleTask> _currentTasks = [];
  bool isQuickAddMode = false;
  Future<bool> _checkIfShownAgain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasShownUnauthenticatedWarning') ?? false;
  }

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
  List<ScheduleTask> _getTasksForSelectedDate() {
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
    try {
      // Add null checks before accessing streams
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Initialize streams here
      }
    } catch (e) {
      print('Initialization error: $e');
    }
    // _notificationService.initialize();
    FirebaseTaskService.getScheduledTasksStream();
    FirebaseTaskService.getQuickTasksStream();
    _startOverdueTimer();
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

  List<ScheduleTask> _getOverdueTasks() {
    return todos.where((task) => _isTaskOverdue(task)).toList();
  }

  bool _isTaskOverdue(ScheduleTask todo) {
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_getMonthName(displayedMonth.month)} ${displayedMonth.year}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textLight,
            ),
          ],
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
      ScheduleTask todo, bool isCurrentlyCompleted) async {
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

  Widget _buildTaskItem(ScheduleTask todo, bool isOverdue) {
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

    Future<void> handleDelete(ScheduleTask todo) async {
      final deletedTodo = todo;

      try {
        // Remove from local list first
        setState(() {
          todos.removeWhere((t) => t.id == todo.id);
        });

        await FirebaseTaskService.deleteScheduledTask(todo.id);

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                try {
                  await FirebaseTaskService.addScheduledTask(deletedTodo);
                } catch (e) {
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
        // If deletion fails, restore the item
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
        await FirebaseTaskService.updateScheduledTask(todo);

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
                    Text('Are you sure you want to delete "${todo.title}"?'),
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
              await handleDelete(todo);
              return true; // Allow the dismissible to remove the item
            }
            return false;
          },
          child: Card(
            color: Colors.white,
            elevation: 3.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Existing checkbox and task details...

                      // Add a reschedule icon for overdue tasks
                      if (isOverdue)
                        IconButton(
                          icon: Icon(Icons.schedule, color: Colors.red),
                          onPressed: () => _showRescheduleDialog(context, todo),
                          tooltip: 'Reschedule Task',
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isOverdue
                          ? SizedBox.shrink() // No checkbox for overdue tasks
                          : Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentCategoryColor.withOpacity(0.1),
                              ),
                              child: Transform.scale(
                                scale: 1.2,
                                child: Checkbox(
                                  value: todo.isCompleted,
                                  onChanged: (bool? newValue) =>
                                      handleMainTaskStatusChange(
                                          newValue, setState),
                                  activeColor: currentCategoryColor,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),

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
                                      await FirebaseTaskService
                                          .updateScheduledTask(todo);
                                    } catch (e) {
                                      // Handle error
                                    }
                                  },
                                  shape: const CircleBorder(),
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

  Widget _buildQuickTaskItem(DailyTask task, BuildContext context) {
    String formatCreationTime(DateTime dateTime) {
      return 'Created at ${DateFormat('h:mm a').format(dateTime).toLowerCase()}';
    }

    Future<bool?> _showCompletionDialog(bool isCurrentlyCompleted) async {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            isCurrentlyCompleted
                ? 'Mark Task as Incomplete?'
                : 'Complete Task?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentlyCompleted
                    ? 'Are you sure you want to mark this task as incomplete?'
                    : 'Are you sure you want to mark this task as complete?',
              ),
              const SizedBox(height: 12),
              Text(task.title),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isCurrentlyCompleted ? 'Mark Incomplete' : 'Complete',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Dismissible(
          key: Key(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) async {
            // Store the task before deletion
            final deletedTask = task.copyWith();

            // Get the ScaffoldMessenger before any async operations
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            try {
              // Delete the task from the database
              await FirebaseTaskService.deleteQuickTask(task.id);

              // Clear existing snackbars
              scaffoldMessenger.clearSnackBars();

              // Show the undo snackbar
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Task deleted'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () async {
                      try {
                        // Restore the task
                        await FirebaseTaskService.addQuickTask(deletedTask);

                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Task restored'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to restore task'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            } catch (e) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Failed to delete task'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          // Rest of the Dismissible widget implementation remains the same
          child: Card(
            color: Colors.white,
            elevation: 3.0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                checkboxTheme: CheckboxThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context).primaryColor;
                    }
                    return Colors.transparent;
                  }),
                  side: BorderSide(
                    color: Colors.grey[400]!,
                    width: 2,
                  ),
                ),
              ),
              child: task.subtasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (task.isCompleted ??
                                    false) // Safely handle null
                                ? Colors.green.withOpacity(0.1)
                                : Colors.indigo.withOpacity(0.1),
                          ),
                          child: Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: task.isCompleted ?? false,
                              onChanged: (bool? value) async {
                                if (value == null) return;

                                final confirmed = await _showCompletionDialog(
                                    task.isCompleted ?? false);
                                if (confirmed == true) {
                                  setState(() {
                                    task.isCompleted = value;
                                  });
                                  await FirebaseTaskService.updateQuickTask(
                                      task);
                                }
                              },
                            ),
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: task.isCompleted == true
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted == true
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(
                                height:
                                    4), // Spacing between title and timestamp
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formatCreationTime(task.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ExpansionTile(
                      leading: Checkbox(
                        value: task.isCompleted ?? false,
                        onChanged: (bool? value) async {
                          if (value == null) return;

                          final confirmed = await _showCompletionDialog(
                              task.isCompleted ?? false);
                          if (confirmed == true) {
                            setState(() {
                              task.isCompleted = value;
                              for (var subtask in task.subtasks) {
                                subtask.isCompleted = value;
                              }
                            });
                            await FirebaseTaskService.updateQuickTask(task);
                          }
                        },
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              decoration: task.isCompleted == true
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted == true
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatCreationTime(task.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: task.subtasks.map((subtask) {
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.only(left: 72, right: 16),
                          leading: Checkbox(
                            value: subtask.isCompleted,
                            onChanged: (bool? value) async {
                              if (value == null) return;

                              // Removed confirmation dialog for subtasks
                              setState(() {
                                subtask.isCompleted = value;
                                bool allSubtasksCompleted =
                                    task.subtasks.every((st) => st.isCompleted);
                                task.isCompleted = allSubtasksCompleted;
                              });
                              await FirebaseTaskService.updateQuickTask(task);
                            },
                          ),
                          title: Text(
                            subtask.title,
                            style: TextStyle(
                              fontSize: 14,
                              decoration: subtask.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: subtask.isCompleted
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget mainContent = _buildTaskList();

    // Choose the appropriate gradient background based on theme mode
    final Widget backgroundWrapper = isDarkMode
        ? HomePageDarkGradientBackground(
            child: _buildScaffold(mainContent),
          )
        : HomePageGradientBackground(
            child: _buildScaffold(mainContent),
          );

    return backgroundWrapper;
  }

  Widget _buildScaffold(Widget mainContent) {
    final overdueTasks = _getOverdueTasks();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile icon on the left
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ProfilePage(
                            scheduledTasks: todos,
                            quickTasks: _quickTasks,
                          )),
                );
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: const Icon(
                  Icons.account_circle,
                  size: 35,
                  color: Colors.white,
                ),
              ),
            ),

            // Overdue tasks indicator on the right
            if (overdueTasks.isNotEmpty)
              GestureDetector(
                onTap: () => _showOverdueTasksBottomSheet(overdueTasks),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Badge(
                    label: Text(
                      overdueTasks.length.toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                ),
              ),
          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (isQuickAddMode) {
            final result = showDailyAddTaskSheet(
              context,
              (DailyTask newTask) {
                setState(() {
                  _quickTasks.add(newTask);
                });
              },
            );

            FirebaseTaskService.getQuickTasksStream();
          } else {
            _showAddTaskDialog();
          }
        },
        backgroundColor: currentCategoryColor ?? Theme.of(context).primaryColor,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTaskTabs() {
    final upcomingTasks = _getTasksForSelectedDate();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTab(
            'Upcoming (${upcomingTasks.length})',
            !isQuickAddMode,
            () {
              setState(() {
                isQuickAddMode = false;
              });
            },
          ),
          const SizedBox(width: 12),
          _buildTab(
            'Daily Tasks',
            isQuickAddMode,
            () {
              setState(() {
                isQuickAddMode = !isQuickAddMode;
              });
            },
            icon: Icons.add_circle_outline,
          ),
        ],
      ),
    );
  }

  Future<void> handleDelete(ScheduleTask todo) async {
    try {
      // Remove from local list first
      setState(() {
        todos.removeWhere((t) => t.id == todo.id);
      });

      // Close bottom sheet if it's the last overdue task
      if (_getOverdueTasks().isEmpty) {
        Navigator.pop(context);
      }

      await FirebaseTaskService.deleteScheduledTask(todo.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              try {
                await FirebaseTaskService.addScheduledTask(todo);
                setState(() {
                  todos.add(todo);
                });
              } catch (e) {
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Modified bottom sheet to update counter
  void _showOverdueTasksBottomSheet(List<ScheduleTask> overdueTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Get fresh count of overdue tasks
          final currentOverdueTasks = _getOverdueTasks();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Overdue Tasks (${currentOverdueTasks.length})',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: currentOverdueTasks.length,
                    itemBuilder: (context, index) {
                      final todo = currentOverdueTasks[index];
                      return Dismissible(
                        key: ValueKey(todo.id),
                        onDismissed: (_) async {
                          await handleDelete(todo);
                          setState(() {}); // Update the bottom sheet UI
                        },
                        // ... rest of your Dismissible implementation
                        child: _buildTaskItem(todo, true),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
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
      setState(() => isLoading = true);

      await _todoSubscription?.cancel();

      _todoSubscription = FirebaseTaskService.getScheduledTasksStream().listen(
        (updatedTodos) {
          if (mounted) {
            setState(() {
              // Create a new list and only add non-deleted tasks
              todos = List<ScheduleTask>.from(updatedTodos)
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error loading todos: $error');
          if (mounted) {
            setState(() => isLoading = false);
          }
        },
      );
    } catch (e) {
      print('Error setting up todos stream: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildTaskList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isQuickAddMode) {
      return StreamBuilder<List<DailyTask>>(
        stream: FirebaseTaskService.getQuickTasksStream(),
        initialData: _quickTasks, // Use cached data initially
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _quickTasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final quickTasks = snapshot.data ?? [];

          // Update cached tasks when new data arrives
          if (snapshot.hasData && snapshot.data != _quickTasks) {
            _quickTasks = snapshot.data!;
          }

          if (quickTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No quick tasks added yet',
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
            key: ValueKey(
                'daily-tasks-${DateTime.now().millisecondsSinceEpoch}'),
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: quickTasks.length,
            itemBuilder: (context, index) {
              final task = quickTasks[index];
              return _buildQuickTaskItem(task, context);
            },
          );
        },
      );
    } else {
      // Handle regular tasks
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
        key: ValueKey('regular-tasks-${DateTime.now().millisecondsSinceEpoch}'),
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
  }

  Future<void> _showRescheduleDialog(
      BuildContext context, ScheduleTask todo) async {
    DateTime selectedDate = todo.dueDate;
    TimeOfDay? selectedTime = todo.dueTime;

    // Get current date and time
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Ensure initialDate is not before today

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.45,
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
                            initialDate: today,
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
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              accentColor: currentCategoryColor,
                            );
                            if (pickedTime != null) {
                              if (pickedTime != null) {
                                setState(() => selectedTime = pickedTime);
                              }
                            }
                          }),
                      SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final now = DateTime.now();
                                final selectedDateTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  selectedTime?.hour ?? now.hour,
                                  selectedTime?.minute ?? now.minute,
                                );

                                // New validation logic
                                if (selectedDateTime.isAfter(now)) {
                                  try {
                                    await FirebaseTaskService
                                        .updateRescheduleScheduledTask(
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
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Please select a future date or time',
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
                                      color: Colors.white),
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

  void _showAddTaskDialog() {
    final TextEditingController titleController = TextEditingController();
    final List<TextEditingController> subtaskControllers = [
      TextEditingController()
    ];
    bool showTitleError = false;
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                                padding: const EdgeInsets.all(8),
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
                                    // Today Option
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
                                    // Tomorrow Option
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
                                              final DateTime? selectedDate =
                                                  await showCustomDatePicker(
                                                context: context,
                                                initialDate:
                                                    selectedDueDate, // Use the currently selected date
                                                firstDate: DateTime
                                                    .now(), // Prevent selecting past dates
                                                lastDate: DateTime.now().add(
                                                    const Duration(
                                                        days:
                                                            365)), // Allow up to 1 year ahead
                                                accentColor:
                                                    currentCategoryColor, // Use your category color
                                              );

                                              if (selectedDate != null) {
                                                setState(() {
                                                  selectedDateType = 'custom';
                                                  selectedDueDate =
                                                      selectedDate;
                                                  // Check if existing time is still valid with new date
                                                  if (selectedDueTime != null &&
                                                      !isValidDueTime(
                                                          selectedDate,
                                                          selectedDueTime!)) {
                                                    selectedDueTime = null;
                                                  }
                                                });
                                              }
                                            },
                                            child: Container(
                                                margin: const EdgeInsets.all(8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                  horizontal: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors.grey[300]!),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  color: selectedDateType ==
                                                          'custom'
                                                      ? currentCategoryColor
                                                      : Colors.transparent,
                                                ),
                                                child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 16,
                                                        color:
                                                            selectedDateType ==
                                                                    'custom'
                                                                ? Colors.white
                                                                : Colors
                                                                    .grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Pick',
                                                        style:
                                                            GoogleFonts.inter(
                                                          color:
                                                              selectedDateType ==
                                                                      'custom'
                                                                  ? Colors.white
                                                                  : Colors.grey[
                                                                      600],
                                                        ),
                                                      ),
                                                    ]))))
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
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                    accentColor: currentCategoryColor,
                                  );
                                  if (pickedTime != null) {
                                    if (isValidDueTime(
                                        selectedDueDate, pickedTime)) {
                                      setState(() {
                                        selectedDueTime = pickedTime;
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
                              setState(() => showTitleError = true);
                              return;
                            }

                            setState(() {
                              showTitleError = false;
                              isLoading = true;
                            });

                            final uuid = Uuid(); // Define this first
                            final newScheduledTask = ScheduleTask(
                              // Define the task before try block
                              id: uuid.v4(),
                              userId: FirebaseAuth.instance.currentUser?.uid ??
                                  'guest_user',
                              title: titleController.text.trim(),
                              description: "",
                              createdAt: DateTime.now(),
                              dueDate: selectedDueDate,
                              dueTime: selectedDueTime,
                              subtasks: subtaskControllers
                                  .where((controller) =>
                                      controller.text.trim().isNotEmpty)
                                  .map((controller) => ScheduleSubTask(
                                        id: uuid.v4(),
                                        title: controller.text.trim(),
                                      ))
                                  .toList(),
                            );

                            try {
                              // Close the bottom sheet first
                              Navigator.of(context).pop();

                              // Optimistic update - use a new list to avoid modifying the original
                              setState(() {
                                todos = List<ScheduleTask>.from(todos)
                                  ..add(newScheduledTask);
                              });

                              // Then update Firebase
                              await FirebaseTaskService.addScheduledTask(
                                  newScheduledTask);

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Task added successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              // Revert optimistic update if Firebase update fails
                              if (mounted) {
                                setState(() {
                                  todos.removeWhere(
                                      (t) => t.id == newScheduledTask.id);
                                });
                              }

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Failed to add task. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            }
                          },
                          child: isLoading
                              ? CircularProgressIndicator()
                              : Text("Add Scheduled Task"),
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

  void showDailyAddTaskSheet(
      BuildContext context, Function(DailyTask) onTaskAdded) {
    final taskTitleController = TextEditingController();
    final subtaskController = TextEditingController();
    final List<DailySubTask> subtasks = [];
    bool isLoading = false;

    void addSubtask() {
      if (subtaskController.text.trim().isNotEmpty) {
        subtasks.add(
          DailySubTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: subtaskController.text.trim(),
          ),
        );
        subtaskController.clear();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Daily Task',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Task Title Field
                    TextField(
                      controller: taskTitleController,
                      decoration: InputDecoration(
                        hintText: 'What needs to be done?',
                        prefixIcon: const Icon(Icons.task_alt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 20),

                    // Subtask Field
                    TextField(
                      controller: subtaskController,
                      decoration: InputDecoration(
                        hintText: 'Add subtask',
                        prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                        suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              addSubtask();
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (value) {
                        setState(() {
                          addSubtask();
                        });
                      },
                    ),

                    // Subtasks List
                    if (subtasks.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Subtasks (${subtasks.length})',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: subtasks.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.grey[200],
                          ),
                          itemBuilder: (context, index) {
                            final subtask = subtasks[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.circle_outlined,
                                size: 16,
                                color: Colors.grey,
                              ),
                              title: Text(
                                subtask.title,
                                style: const TextStyle(fontSize: 15),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red[400],
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    subtasks.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Add Task Button
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final user = FirebaseAuth.instance.currentUser;

                                if (taskTitleController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please enter a task title'),
                                    ),
                                  );
                                  return;
                                }

                                // Add any remaining subtask that hasn't been added
                                if (subtaskController.text.trim().isNotEmpty) {
                                  setState(() {
                                    addSubtask();
                                  });
                                }

                                setState(() {
                                  isLoading = true;
                                });

                                // Simulate loading for 2 seconds

                                try {
                                  // Check network connectivity

                                  final newTask = DailyTask(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    userId: FirebaseAuth
                                            .instance.currentUser?.uid ??
                                        'guest_user', // Use authenticated user ID or fallback to 'guest_user'

                                    title: taskTitleController.text.trim(),
                                    createdAt: DateTime.now(),
                                    subtasks: List.from(subtasks),
                                  );

                                  // Close the bottom sheet after successful task addition
                                  Navigator.of(context).pop();
                                  await FirebaseTaskService.addQuickTask(
                                      newTask);
                                } finally {
                                  setState(() {
                                    isLoading = false;
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Add Task',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
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

  Future<TimeOfDay?> showTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    required Color accentColor,
  }) async {
    return showModalBottomSheet(
      context: context,
      builder: (context) => TimePicker(
        onTimeSelected: (TimeOfDay time) {
          print('Selected time: ${time.format(context)}');
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<DateTime?> showCustomDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    required Color accentColor,
  }) async {
    // Set default values for firstDate and lastDate if not provided
    firstDate ??= DateTime.now();
    lastDate ??=
        DateTime.now().add(const Duration(days: 365)); // One year from now

    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) => CustomDatePicker(
        initialDate: initialDate,
        firstDate: firstDate!,
        lastDate: lastDate!,
        accentColor: accentColor,
        onDateSelected: (DateTime date) {
          print('Selected date: ${date.toString()}');
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          padding: const EdgeInsets.all(8.0),
          child: Container(
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
        ),
      ],
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

class ModernTimePicker extends StatefulWidget {
  final DateTime? initialTime;
  final Function(DateTime) onTimeSelected;
  final DateTime? minTime;

  const ModernTimePicker({
    Key? key,
    this.initialTime,
    required this.onTimeSelected,
    this.minTime,
  }) : super(key: key);

  @override
  _ModernTimePickerState createState() => _ModernTimePickerState();
}

class _ModernTimePickerState extends State<ModernTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late DateTime _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime ?? DateTime.now();
    _hourController = FixedExtentScrollController(
      initialItem: _selectedTime.hour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedTime.minute ~/ 5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  'Set Time',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onTimeSelected(_selectedTime);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Time Picker Wheels
          Expanded(
            child: Row(
              children: [
                _buildTimePicker(
                  controller: _hourController,
                  items: List.generate(24, (index) => index),
                  onChanged: (int value) {
                    setState(() {
                      _selectedTime = DateTime(
                        _selectedTime.year,
                        _selectedTime.month,
                        _selectedTime.day,
                        value,
                        _selectedTime.minute,
                      );
                    });
                  },
                  formatValue: (value) => value.toString().padLeft(2, '0'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildTimePicker(
                  controller: _minuteController,
                  items: List.generate(12, (index) => index * 5),
                  onChanged: (int value) {
                    setState(() {
                      _selectedTime = DateTime(
                        _selectedTime.year,
                        _selectedTime.month,
                        _selectedTime.day,
                        _selectedTime.hour,
                        value,
                      );
                    });
                  },
                  formatValue: (value) => value.toString().padLeft(2, '0'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required FixedExtentScrollController controller,
    required List<int> items,
    required Function(int) onChanged,
    required String Function(int) formatValue,
  }) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 50,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: FixedExtentScrollPhysics(),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            return Container(
              height: 50,
              alignment: Alignment.center,
              child: Text(
                formatValue(items[index]),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: controller.selectedItem == index
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: controller.selectedItem == index
                      ? Colors.black
                      : Colors.grey[400],
                ),
              ),
            );
          },
        ),
        onSelectedItemChanged: (index) => onChanged(items[index]),
      ),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }
}

// Custom Bottom Sheet to show the time picker
void showModernTimePicker(
  BuildContext context, {
  required Function(DateTime) onTimeSelected,
  DateTime? initialTime,
  DateTime? minTime,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ModernTimePicker(
      initialTime: initialTime,
      onTimeSelected: onTimeSelected,
      minTime: minTime,
    ),
  );
}
