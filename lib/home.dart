import 'package:flutter/material.dart';
import 'todo_service.dart';

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
  final TextEditingController newTodoController = TextEditingController();
  final FocusNode _newTodoFocus = FocusNode();
  bool isCurrentLineEmpty = true;
  final ScrollController _calendarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    todos = widget.existingTodoList?.todos ?? [];
    selectedDate = DateTime.now();
    displayedMonth = DateTime.now();
    currentCategory = widget.todoListData?.category ?? 'Personal';
    currentCategoryColor = widget.todoListData?.categoryColor ?? Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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

  Widget _buildTaskTabs() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          _buildTab('All tasks', true),
          SizedBox(width: 16),
          _buildTab('My tasks', false),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected) {
    return Container(
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
    );
  }void _showAddTaskDialog() {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime selectedDueDate = DateTime.now();
  TimeOfDay? selectedDueTime;
  String selectedDateType = 'today'; // 'today', 'tomorrow', 'custom'

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add task',
                      style: TextStyle(
                        fontSize: 20,
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
                
                // Title Field
                TextField(
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
                SizedBox(height: 16),
                
                // Description Field
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter task description',
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
                      // Quick Date Options
                      Row(
                        children: [
                          _buildDateOption(
                            'Today',
                            selectedDateType == 'today',
                            () => setState(() {
                              selectedDateType = 'today';
                              selectedDueDate = DateTime.now();
                            }),
                          ),
                          _buildDateOption(
                            'Tomorrow',
                            selectedDateType == 'tomorrow',
                            () => setState(() {
                              selectedDateType = 'tomorrow';
                              selectedDueDate = DateTime.now().add(Duration(days: 1));
                            }),
                          ),
                          _buildDateOption(
                            'Custom',
                            selectedDateType == 'custom',
                            () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2025),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDateType = 'custom';
                                  selectedDueDate = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      
                      // Selected Date Display
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: currentCategoryColor),
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

                // Time Selection
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
                          'Due Time (Optional)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.access_time),
                        title: Text(
                          selectedDueTime != null
                              ? '${selectedDueTime!.format(context)}'
                              : 'Set time',
                        ),
                        trailing: selectedDueTime != null
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () => setState(() => selectedDueTime = null),
                              )
                            : null,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() => selectedDueTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Add Task Button
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      setState(() {
                        todos.add(TodoItem(
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          createdAt: DateTime.now(),
                          dueDate: selectedDueDate,
                          dueTime: selectedDueTime,
                        ));
                      });
                      Navigator.pop(context);
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
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildDateOption(String text, bool isSelected, VoidCallback onTap) {
  return Expanded(
    child: GestureDetector(
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
          ),
        ),
      ),
    ),
  );
}

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
                  '${_getMonthName(displayedMonth.month)} ${displayedMonth.year}',
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
          PopupMenuButton<int>(
            child: Row(
              children: [
                Text(
                  '${displayedMonth.year}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_drop_down),
              ],
            ),
            onSelected: (int year) {
              setState(() {
                displayedMonth = DateTime(year, displayedMonth.month);
                selectedDate =
                    DateTime(year, displayedMonth.month, selectedDate.day);
              });
            },
            itemBuilder: (BuildContext context) {
              final currentYear = DateTime.now().year;
              return List.generate(5, (index) {
                final year = currentYear - 2 + index;
                return PopupMenuItem<int>(
                  value: year,
                  child: Text('$year'),
                );
              });
            },
          ),
        ],
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

  Widget _buildCalendar() {
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
            itemCount: _getDaysInMonth(displayedMonth),
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final date = DateTime(
                displayedMonth.year,
                displayedMonth.month,
                index + 1,
              );
              final isSelected = selectedDate.year == date.year &&
                  selectedDate.month == date.month &&
                  selectedDate.day == date.day;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

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
                            : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      if (isSelected)
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
                          color: isSelected ? Colors.white : Colors.grey,
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
                                  : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Add dot indicator for tasks
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

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  bool _hasTasksOnDate(DateTime date) {
    return todos.any((todo) {
      final todoDate = todo.createdAt;
      return todoDate.year == date.year &&
          todoDate.month == date.month &&
          todoDate.day == date.day;
    });
  }

  List<TodoItem> _getTasksForSelectedDate() {
    return todos.where((todo) {
      final todoDate = todo.createdAt;
      return todoDate.year == selectedDate.year &&
          todoDate.month == selectedDate.month &&
          todoDate.day == selectedDate.day;
    }).toList();
  }

  // ... (rest of the existing code remains the same)

  Widget _buildTaskList() {
    final tasksForDate = _getTasksForSelectedDate();

    if (tasksForDate.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 48,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No tasks for ${_getMonthName(selectedDate.month)} ${selectedDate.day}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: tasksForDate.length,
      itemBuilder: (context, index) {
        final todo = tasksForDate[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Checkbox(
              value: todo.isCompleted,
              onChanged: (value) {
                setState(() {
                  todo.isCompleted = value ?? false;
                  todo.completedAt = value ?? false ? DateTime.now() : null;
                });
              },
              activeColor: currentCategoryColor,
              shape: CircleBorder(),
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                decoration:
                    todo.isCompleted ? TextDecoration.lineThrough : null,
                color: todo.isCompleted ? Colors.grey : Colors.black87,
              ),
            ),
            trailing: Icon(Icons.star_border, color: Colors.amber),
          ),
        );
      },
    );
  }
}
