import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title Tasks (${tasks.length})',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Divider(),
            if (tasks.isEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tasks'),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final taskDueDateTime = DateTime(
                      task.dueDate.year,
                      task.dueDate.month,
                      task.dueDate.day,
                      task.dueTime?.hour ?? 23,
                      task.dueTime?.minute ?? 59,
                    );

                    final now = DateTime.now();
                    final difference = taskDueDateTime.difference(now);

                    String timeStatus;
                    if (_isTaskOverdue(task)) {
                      if (difference.inDays < -1) {
                        timeStatus = 'Overdue by ${-difference.inDays} days';
                      } else if (difference.inHours < -1) {
                        timeStatus = 'Overdue by ${-difference.inHours} hours';
                      } else {
                        timeStatus =
                            'Overdue by ${-difference.inMinutes} minutes';
                      }
                    } else {
                      if (difference.inDays > 0) {
                        timeStatus = 'Due in ${difference.inDays} days';
                      } else if (difference.inHours > 0) {
                        timeStatus = 'Due in ${difference.inHours} hours';
                      } else {
                        timeStatus = 'Due in ${difference.inMinutes} minutes';
                      }
                    }

                    return ListTile(
                      leading: Icon(
                        _isTaskOverdue(task) ? Icons.warning : Icons.schedule,
                        color:
                            _isTaskOverdue(task) ? Colors.red : Colors.orange,
                      ),
                      title: Text(task.title),
                      subtitle: Text(timeStatus),
                    );
                  },
                ),
              ),
          ],
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<TodoItem>>(
        stream: _todoStorage.getTodosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data ?? [];

          // Get all task categories using the new methods
          final completedTasks =
              todos.where((todo) => todo.isCompleted).toList();
          final overdueTasks = _getOverdueTasks(todos);
          final pendingTasks = _getPendingTasks(todos);

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Profile Header
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _showImagePickerOptions,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue, width: 2),
                              color: Colors.blue[50],
                              image: _profileImage != null
                                  ? DecorationImage(
                                      fit: BoxFit.cover,
                                      image: FileImage(_profileImage!),
                                    )
                                  : null,
                            ),
                            child: _profileImage == null
                                ? Icon(Icons.camera_alt,
                                    size: 40, color: Colors.blue)
                                : null,
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: _isEditingName
                              ? TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.check),
                                      onPressed: () {
                                        setState(() {
                                          _isEditingName = false;
                                        });
                                      },
                                    ),
                                  ),
                                  autofocus: true,
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _nameController.text,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit),
                                      onPressed: () {
                                        setState(() {
                                          _isEditingName = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Completed',
                        '${completedTasks.length}',
                        Icons.check_circle,
                        Colors.green,
                        onTap: () => _showTaskDetailsBottomSheet(
                            'Completed', completedTasks),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        '${pendingTasks.length}',
                        Icons.pending_actions,
                        Colors.orange,
                        onTap: () => _showTaskDetailsBottomSheet(
                            'Pending', pendingTasks),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Overdue',
                        '${overdueTasks.length}',
                        Icons.warning,
                        Colors.red,
                        onTap: () => _showTaskDetailsBottomSheet(
                            'Overdue', overdueTasks),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Progress',
                        '${((completedTasks.length / (todos.isEmpty ? 1 : todos.length)) * 100).toStringAsFixed(0)}%',
                        Icons.pie_chart,
                        Colors.blue,
                        showProgress: true,
                        progress: todos.isEmpty
                            ? 0
                            : completedTasks.length / todos.length,
                      ),
                    ),
                  ],
                ),

                // Settings section remains the same...
                SizedBox(height: 24),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        'Notifications',
                        Icons.notifications,
                        Colors.red,
                        context,
                      ),
                      Divider(height: 1),
                      _buildSettingsTile(
                        'Theme',
                        Icons.palette,
                        Colors.purple,
                        context,
                      ),
                      Divider(height: 1),
                      _buildSettingsTile(
                        'Categories',
                        Icons.category,
                        Colors.green,
                        context,
                      ),
                      _buildSettingsTile(
                        'Sign Out',
                        Icons.logout,
                        Colors.red,
                        context,
                        onTap: () async {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
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

  Widget _buildSettingsTile(
      String title, IconData icon, Color color, BuildContext context,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: Icon(Icons.chevron_right),
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title settings coming soon')),
            );
          },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool showProgress = false,
    double progress = 0,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              if (showProgress) ...[
                CircularPercentIndicator(
                  radius: 25,
                  lineWidth: 5,
                  percent: progress,
                  center: Icon(icon, color: color, size: 24),
                  progressColor: color,
                  backgroundColor: color.withOpacity(0.2),
                ),
              ] else
                Icon(icon, color: color, size: 32),
              SizedBox(height: 12),
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
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildSettingsTile remains the same...
}
