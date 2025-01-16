import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfilePage extends StatefulWidget {
  final List<TodoItem> todos;
  ProfilePage({Key? key, required this.todos}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TodoStorage _todoStorage = TodoStorage();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController =
      TextEditingController(text: 'User Name');
  bool _isEditingName = false;
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions first
      PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        status = await Permission.storage.request();
      }

      if (status.isGranted) {
        final pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          setState(() {
            _profileImage = File(pickedFile.path);
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission denied. Please enable it in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera),
              title: Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetailsBottomSheet(String title, List<TodoItem> tasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$title Tasks (${tasks.length})',
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
              Divider(),
              if (tasks.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No tasks'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tasks.length,
                    itemBuilder: (context, index) => _TaskListItem(
                      task: tasks[index],
                      gridType: title.toLowerCase(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<TodoItem> _getOverdueTasks(List<TodoItem> todos) {
    return todos.where((task) => _isTaskOverdue(task)).toList();
  }

  bool _isTaskOverdue(TodoItem task) {
    if (task.isCompleted) return false; // Completed tasks are not overdue
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

  List<TodoItem> _getPendingTasks(List<TodoItem> todos) {
    return todos
        .where((task) =>
                !task.isCompleted && // Not completed
                !_isTaskOverdue(task) // Not overdue
            )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<TodoItem>>(
        stream: _todoStorage.getTodosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data ?? [];
          final completedTasks =
              todos.where((todo) => todo.isCompleted).toList();
          final overdueTasks = _getOverdueTasks(todos);
          final pendingTasks = _getPendingTasks(todos);
          double progressValue =
              todos.isEmpty ? 0 : completedTasks.length / todos.length;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 340,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(color: Colors.white),
                    child: SafeArea(
                      child: Stack(
                        children: [
                          // Progress Indicator positioned at top right
                          Positioned(
                            top: 20,
                            right: 20,
                            child: Container(
                              width: 120,
                              height: 120,
                              child: CircularPercentIndicator(
                                radius: 60,
                                lineWidth: 12,
                                percent: progressValue,
                                center: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${(progressValue * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 28,
                                      ),
                                    ),
                                    Text(
                                      'Complete',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                progressColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey[200]!,
                                circularStrokeCap: CircularStrokeCap.round,
                              ),
                            ),
                          ),
                          // Profile content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 20),
                              // Profile Image with Edit Button
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  GestureDetector(
                                    onTap: _showImagePickerOptions,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 4),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage: _profileImage != null
                                            ? FileImage(_profileImage!)
                                                as ImageProvider
                                            : null,
                                        child: _profileImage == null
                                            ? Icon(Icons.person,
                                                size: 60,
                                                color: Colors.grey[400])
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.camera_alt,
                                        size: 20,
                                        color: Theme.of(context).primaryColor),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              // User Name with Edit
                              if (_isEditingName)
                                Container(
                                  width: 200,
                                  child: TextField(
                                    controller: _nameController,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    decoration: InputDecoration(
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.check,
                                            color:
                                                Theme.of(context).primaryColor),
                                        onPressed: () => setState(
                                            () => _isEditingName = false),
                                      ),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _isEditingName = true),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _nameController.text,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.edit,
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.8),
                                          size: 20),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Statistics Cards
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Task Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildEnhancedStatCard(
                              'Completed',
                              completedTasks.length.toString(),
                              Icons.check_circle_outline,
                              Colors.green[700]!,
                              onTap: () => _showTaskDetailsBottomSheet(
                                  'Completed', completedTasks),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildEnhancedStatCard(
                              'Pending',
                              pendingTasks.length.toString(),
                              Icons.pending_actions,
                              Colors.orange[700]!,
                              onTap: () => _showTaskDetailsBottomSheet(
                                  'Pending', pendingTasks),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildEnhancedStatCard(
                              'Overdue',
                              overdueTasks.length.toString(),
                              Icons.warning_outlined,
                              Colors.red[700]!,
                              onTap: () => _showTaskDetailsBottomSheet(
                                  'Overdue', overdueTasks),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Settings Section
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Divider(height: 1, indent: 70),
                            _buildEnhancedSettingsTile(
                              'Notifications',
                              Icons.notifications_none,
                              Colors.orange[700]!,
                              context,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Padding
              SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnhancedStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedSettingsTile(
    String title,
    IconData icon,
    Color color,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title settings coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
    );
  }
}

class _TaskListItem extends StatefulWidget {
  final TodoItem task;
  final String gridType;

  const _TaskListItem({
    Key? key,
    required this.task,
    required this.gridType,
  }) : super(key: key);

  @override
  _TaskListItemState createState() => _TaskListItemState();
}

class _TaskListItemState extends State<_TaskListItem> {
  bool isExpanded = false;

  String _formatDateTime(DateTime dateTime) {
    // Format date as "MMM dd, yyyy" (e.g., "Jan 14, 2025")
    String date = DateFormat('MMM dd, yyyy').format(dateTime);
    // Format time as "h:mm a" (e.g., "2:30 PM")
    String time = DateFormat('h:mm a').format(dateTime);
    return '$date at $time';
  }

  Color _getTimeColor() {
    switch (widget.gridType) {
      case 'completed':
        return Colors.green.shade700;
      case 'pending':
        return Colors.blue.shade700;
      case 'overdue':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    String timeInfo = '';
    Icon leadingIcon;

    // Set time information and icon based on grid type
    if (widget.gridType == 'completed') {
      timeInfo =
          'Completed: ${_formatDateTime(widget.task.completedAt ?? DateTime.now())}';
      leadingIcon = Icon(Icons.check_circle, color: Colors.green.shade600);
    } else if (widget.gridType == 'pending') {
      String dueDate = DateFormat('MMM dd, yyyy').format(widget.task.dueDate);
      timeInfo = 'Due: $dueDate';
      if (widget.task.dueTime != null) {
        String dueTime = DateFormat('h:mm a').format(DateTime(
          widget.task.dueDate.year,
          widget.task.dueDate.month,
          widget.task.dueDate.day,
          widget.task.dueTime!.hour,
          widget.task.dueTime!.minute,
        ));
        timeInfo += ' at $dueTime';
      }
      leadingIcon = Icon(Icons.pending_actions, color: Colors.blue.shade600);
    } else {
      // overdue
      timeInfo = 'Past Due: ${_formatDateTime(DateTime(
        widget.task.dueDate.year,
        widget.task.dueDate.month,
        widget.task.dueDate.day,
        widget.task.dueTime?.hour ?? 23,
        widget.task.dueTime?.minute ?? 59,
      ))}';
      leadingIcon = Icon(Icons.warning_rounded, color: Colors.red.shade600);
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getTimeColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: leadingIcon,
            title: Text(
              widget.task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: widget.task.subtasks.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade700,
                    ),
                    onPressed: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  )
                : null,
            subtitle: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                timeInfo,
                style: TextStyle(
                  color: _getTimeColor(),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (isExpanded && widget.task.subtasks.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtasks:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...widget.task.subtasks
                      .map(
                        (subtask) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                subtask.isCompleted
                                    ? Icons.check_circle
                                    : Icons.list,
                                size: 20,
                                color: subtask.isCompleted
                                    ? Colors.green.shade500
                                    : Colors.grey.shade400,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subtask.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    decoration: subtask.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
