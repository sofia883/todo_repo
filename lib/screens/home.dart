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

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    displayedMonth = DateTime.now();
    currentCategory = widget.todoListData?.category ?? 'Personal';
    currentCategoryColor = widget.todoListData?.categoryColor ?? Colors.indigo;
    todos = [];
    _loadTodos();
  }

  @override
  void dispose() {
    _todoSubscription?.cancel(); // Cancel subscription when disposing
    super.dispose();
  }

  final TodoStorage _todoStorage = TodoStorage();
  Future<void> _loadTodos() async {
    try {
      // Set loading state only initially
      if (todos.isEmpty) {
        setState(() {
          isLoading = true;
        });
      }

      // Cancel existing subscription if any
      await _todoSubscription?.cancel();

      // Create new subscription
      _todoSubscription = _todoStorage.getTodosStream().listen(
        (updatedTodos) {
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

  // Update the task tabs to be tappable
  Widget _buildTaskTabs() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          _buildTab('All tasks', !showMyTasksOnly, () {
            setState(() => showMyTasksOnly = false);
          }),
          SizedBox(width: 16),
          _buildTab('My tasks', showMyTasksOnly, () {
            setState(() => showMyTasksOnly = true);
          }),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected, VoidCallback onTap) {
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

  // Update the add task method to save todos

  bool _hasTasksOnDate(DateTime date) {
    return todos.any((todo) {
      final todoDate = todo.dueDate; // Changed from createdAt to dueDate
      return todoDate.year == date.year &&
          todoDate.month == date.month &&
          todoDate.day == date.day;
    });
  }

  List<TodoItem> _getTasksForSelectedDate() {
    return todos.where((todo) {
      final todoDate = todo.dueDate; // Changed from createdAt to dueDate
      return todoDate.year == selectedDate.year &&
          todoDate.month == selectedDate.month &&
          todoDate.day == selectedDate.day;
    }).toList();
  }
// Part 1: Task Input Validation and Dialog remains the same as before, just remove the star icon related code

// Part 2: Updated Task List Item Display with improved UI
  Widget _buildTaskList() {
    final tasksForDate = _getTasksForSelectedDate();

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
              'No tasks for ${_getMonthName(selectedDate.month)} ${selectedDate.day}',
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

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tasksForDate.length,
      itemBuilder: (context, index) {
        final todo = tasksForDate[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: currentCategoryColor.withOpacity(0.08),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: InkWell(
              onTap: () {
                setState(() {
                  todo.isCompleted = !todo.isCompleted;
                  todo.completedAt = todo.isCompleted ? DateTime.now() : null;
                });
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: todo.isCompleted
                      ? currentCategoryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: todo.isCompleted
                        ? currentCategoryColor
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: todo.isCompleted
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title.isEmpty ? 'Untitled Task' : todo.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration:
                        todo.isCompleted ? TextDecoration.lineThrough : null,
                    color: todo.isCompleted ? Colors.grey[400] : Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  todo.description,
                  style: TextStyle(
                    fontSize: 14,
                    decoration:
                        todo.isCompleted ? TextDecoration.lineThrough : null,
                    color:
                        todo.isCompleted ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: todo.dueTime != null
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentCategoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: currentCategoryColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          todo.dueTime!.format(context),
                          style: TextStyle(
                            color: currentCategoryColor,
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
        showDescriptionError = descriptionController.text.trim().isEmpty;
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
                valueColor: AlwaysStoppedAnimation<Color>(currentCategoryColor),
              ),
            ),
          );

          await _todoStorage.createTodo(newTodo);
          
          // Close loading indicator and dialog
          Navigator.of(context).pop(); // Close loading indicator
          Navigator.of(context).pop(); // Close add task dialog
          
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
