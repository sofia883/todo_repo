import 'dart:async';
import 'package:flutter/material.dart';
import 'package:to_do_app/screens/profile_page.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:to_do_app/data/to_do_storage.dart';

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
  // Add confirmation dialog for task completion
  Future<bool> _showTaskCompletionDialog(TodoItem todo) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Complete Task?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark this task as complete?',
              ),
              SizedBox(height: 12),
              Text(
                todo.title,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
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
              child: Text('Complete'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  List<TodoItem> _getTasksForSelectedDate() {
    final now = DateTime.now();
    return todos.where((todo) {
      if (todo.isCompleted) return false; // Filter out completed tasks

      final todoDate = todo.dueDate;
      final todoDateTime = todo.dueTime != null
          ? DateTime(
              todoDate.year,
              todoDate.month,
              todoDate.day,
              todo.dueTime!.hour,
              todo.dueTime!.minute,
            )
          : DateTime(todoDate.year, todoDate.month, todoDate.day, 23, 59);

      // Check if the task is for the selected date
      final isMatchingDate = todoDate.year == selectedDate.year &&
          todoDate.month == selectedDate.month &&
          todoDate.day == selectedDate.day;

      // Check if the task is not overdue
      final isNotOverdue = todoDateTime.isAfter(now);

      return isMatchingDate && isNotOverdue;
    }).toList();
  }

// Update the _getOverdueTasks method to show only overdue and non-completed tasks
  List<TodoItem> _getOverdueTasks() {
    final now = DateTime.now();
    return todos.where((todo) {
      if (todo.isCompleted) return false; // Filter out completed tasks

      final todoDate = todo.dueDate;
      final todoDateTime = todo.dueTime != null
          ? DateTime(
              todoDate.year,
              todoDate.month,
              todoDate.day,
              todo.dueTime!.hour,
              todo.dueTime!.minute,
            )
          : DateTime(todoDate.year, todoDate.month, todoDate.day, 23, 59);

      return todoDateTime.isBefore(now); // Only return overdue tasks
    }).toList();
  }

// Update _hasTasksOnDate to exclude completed and overdue tasks
  bool _hasTasksOnDate(DateTime date) {
    final now = DateTime.now();
    return todos.any((todo) {
      if (todo.isCompleted) return false; // Filter out completed tasks

      final todoDate = todo.dueDate;
      final todoDateTime = todo.dueTime != null
          ? DateTime(
              todoDate.year,
              todoDate.month,
              todoDate.day,
              todo.dueTime!.hour,
              todo.dueTime!.minute,
            )
          : DateTime(todoDate.year, todoDate.month, todoDate.day, 23, 59);

      final isMatchingDate = todoDate.year == date.year &&
          todoDate.month == date.month &&
          todoDate.day == date.day;

      final isNotOverdue = todoDateTime.isAfter(now);

      return isMatchingDate && isNotOverdue;
    });
  }

  Widget _buildTab(String text, bool isSelected, VoidCallback onTap,
      {double fontSize = 20}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]
              : null,
        ),
        child: Row(
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                color: isSelected ? Colors.black : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: currentCategoryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${todos.length}',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

// Add debug print in initState
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

// Update _loadTodos to include debug information
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
          print(
              'Received ${updatedTodos.length} todos from stream'); // Debug print
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

  @override
  void dispose() {
    _todoSubscription?.cancel(); // Cancel subscription when disposing
    super.dispose();
  }

  // Update the build method to remove duplicate year display
  Widget _buildMonthYearSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month Dropdown
          PopupMenuButton<DateTime>(
            child: Row(
              children: [
                Text(
                  _getMonthName(displayedMonth.month),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_drop_down),
              ],
            ),
            onSelected: (DateTime date) {
              setState(() {
                displayedMonth = date;
                selectedDate = date;
              });
            },
            itemBuilder: (BuildContext context) {
              return List.generate(12, (index) {
                final month = DateTime(displayedMonth.year, index + 1);
                return PopupMenuItem<DateTime>(
                  value: month,
                  child: Text(_getMonthName(month.month)),
                );
              });
            },
          ),
          // Year Dropdown
        ],
      ),
    );
  }

// // Add method to get overdue tasks
// List<TodoItem> _getOverdueTasks() {
//   final now = DateTime.now();
//   return todos.where((todo) {
//     if (todo.isCompleted) return false;

//     final todoDate = todo.dueDate;
//     final todoDateTime = todo.dueTime != null
//         ? DateTime(
//             todoDate.year,
//             todoDate.month,
//             todoDate.day,
//             todo.dueTime!.hour,
//             todo.dueTime!.minute,
//           )
//         : todoDate;

//     return todoDateTime.isBefore(now);
//   }).toList();
// }

// // Update _buildTaskTabs to include overdue tasks count
// Widget _buildTaskTabs() {
//   final overdueTasks = _getOverdueTasks();

//   return Padding(
//     padding: EdgeInsets.all(16),
//     child: Row(
//       children: [
//         _buildTab('All tasks', !showMyTasksOnly, () {
//           setState(() => showMyTasksOnly = false);
//         }),
//         SizedBox(width: 16),
//         _buildTab('My tasks (${overdueTasks.length} overdue)', showMyTasksOnly, () {
//           setState(() => showMyTasksOnly = true);
//         }),
//       ],
//     ),
//   );
// }

// Update _buildTaskList to show overdue tasks in My Tasks section
  Widget _buildTaskList() {
    final tasksForDate =
        showMyTasksOnly ? _getOverdueTasks() : _getTasksForSelectedDate();

    if (tasksForDate.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey[200],
            ),
            SizedBox(height: 16),
            Text(
              showMyTasksOnly
                  ? 'No overdue tasks'
                  : 'No tasks for ${_getMonthName(selectedDate.month)} ${selectedDate.day}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap + to add a new task',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight,
            maxWidth: constraints.maxWidth,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: tasksForDate.length,
            itemBuilder: (context, index) {
              final todo = tasksForDate[index];
              final isOverdue = _getOverdueTasks().contains(todo);

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red[50] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isOverdue
                          ? const Color.fromARGB(255, 73, 40, 38)
                              .withOpacity(0.08)
                          : currentCategoryColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (bool? value) async {
                      if (value != null) {
                        // Show confirmation dialog
                        final shouldComplete =
                            await _showTaskCompletionDialog(todo);
                        if (shouldComplete) {
                          bool wasCompleted = todo.isCompleted;
                          setState(() {
                            todo.isCompleted = value;
                            todo.completedAt = value ? DateTime.now() : null;
                          });

                          try {
                            await _todoStorage.updateTodoStatus(todo.id, value);
                          } catch (e) {
                            setState(() {
                              todo.isCompleted = wasCompleted;
                              todo.completedAt =
                                  wasCompleted ? DateTime.now() : null;
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
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              todo.title.isEmpty ? 'Untitled Task' : todo.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.isCompleted
                                    ? Colors.grey[400]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isOverdue)
                            TextButton(
                              onPressed: () =>
                                  _showRescheduleDialog(context, todo),
                              child: Text('Reschedule'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      if (todo.description.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          todo.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: todo.dueTime != null
                      ? Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                color: isOverdue
                                    ? Colors.red
                                    : currentCategoryColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                todo.dueTime!.format(context),
                                style: TextStyle(
                                  color: isOverdue
                                      ? Colors.red
                                      : currentCategoryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
  // Update the task tabs to be tappable
  // Add this import at the top of your file

// Add this method to your _TodoListState class
  Future<void> _showRescheduleDialog(
      BuildContext context, TodoItem todo) async {
    DateTime selectedDate = todo.dueDate;
    TimeOfDay? selectedTime = todo.dueTime;

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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 24),
                      ListTile(
                        leading: Icon(Icons.calendar_today),
                        title: Text('Due Date'),
                        subtitle: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
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
                        title: Text('Due Time'),
                        subtitle: Text(
                          selectedTime?.format(context) ?? 'No time set',
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
                                try {
                                  await _todoStorage.updateTodoDate(
                                    todo.id,
                                    selectedDate,
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Task rescheduled successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to reschedule task'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Reschedule',
                                  style: TextStyle(fontSize: 16),
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

    // Create a list of dates
    List<DateTime> orderedDates = [];

    // Add dates from the current month
    for (int i = (displayedMonth.year == today.year &&
                displayedMonth.month == today.month)
            ? today.day
            : 1;
        i <= daysInMonth;
        i++) {
      orderedDates.add(DateTime(displayedMonth.year, displayedMonth.month, i));
    }

    // If the total dates are less than 30, add remaining days from the next month
    if (orderedDates.length < 30) {
      final nextMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
      final daysToAdd = 31 - orderedDates.length;

      for (int i = 1; i <= daysToAdd; i++) {
        orderedDates.add(DateTime(nextMonth.year, nextMonth.month, i));
      }
    }

    // Limit to at most 31 days
    orderedDates = orderedDates.take(31).toList();

    return Column(
      children: [
        // Weekday headers
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        SizedBox(height: 8),
        // Calendar days
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
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? currentCategoryColor
                        : isToday
                            ? currentCategoryColor.withOpacity(0.1)
                            : isNextMonth
                                ? Colors.grey[100]
                                : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      if (isSelected || isToday)
                        BoxShadow(
                          color: currentCategoryColor.withOpacity(0.3),
                          blurRadius: 8,
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
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isNextMonth
                                  ? Colors.grey[400]
                                  : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? currentCategoryColor
                                  : isNextMonth
                                      ? Colors.grey[400]
                                      : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_hasTasksOnDate(date))
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : currentCategoryColor,
                          ),
                        ),
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
    final TextEditingController descriptionController = TextEditingController();
    DateTime selectedDueDate = DateTime.now();
    TimeOfDay? selectedDueTime;
    String selectedDateType = 'today';
    bool showDescriptionError = false;
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

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
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
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
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
                                decoration: InputDecoration(
                                  labelText: 'Task Title',
                                  hintText: 'Enter task title',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: Icon(Icons.task_alt),
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
                                      child: Text(title),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Description Field
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Enter task description',
                            errorText: showDescriptionError
                                ? 'Description is required'
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.description),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Date Selection
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
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Quick Date Options in a single row with fixed width
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
                                                style: TextStyle(
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
                                      style: TextStyle(
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

                        // Time Selection with Validation
                        // Updated Time Selection
                        // In _showAddTaskDialog, add this variable at the beginning:

// Replace the time selection container with this updated version:
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
                                  style: TextStyle(
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
                                    style: TextStyle(
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
                            setState(() {
                              showDescriptionError =
                                  descriptionController.text.trim().isEmpty;
                            });

                            if (!showDescriptionError) {
                              final newTodo = TodoItem(
                                title: titleController.text.trim(),
                                description: descriptionController.text.trim(),
                                createdAt: DateTime.now(),
                                dueDate: selectedDueDate,
                                dueTime: selectedDueTime,
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

                                await _todoStorage.createTodo(newTodo);

                                // Close loading indicator and dialog
                                Navigator.of(context)
                                    .pop(); // Close loading indicator
                                Navigator.of(context)
                                    .pop(); // Close add task dialog

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Task added successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                // Close loading indicator if still showing
                                Navigator.of(context).pop();

                                // Show error message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().contains('PERMISSION_DENIED')
                                          ? 'Permission denied. Please sign in again.'
                                          : 'Failed to add task. Please try again.',
                                    ),
                                    backgroundColor: Colors.red,
                                    action: SnackBarAction(
                                      label: 'Retry',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        // Add retry logic here
                                        _todoStorage.createTodo(newTodo);
                                      },
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Add Task',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentCategoryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }
}
