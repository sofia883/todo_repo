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

  // Image picker methods remain the same...
  // [Previous image picker methods here]
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FF),
      body: StreamBuilder<List<TodoItem>>(
        stream: HybridStorageService.getScheduledTasksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data ?? [];
          final completedTasks =
              todos.where((todo) => todo.isCompleted).toList();
          final pendingTasks = _getPendingTasks(todos);
          final totalTasks = todos.length;

          return CustomScrollView(
            slivers: [
              // Modern Profile Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Profile Image
                          _buildProfileImage(),
                          SizedBox(height: 15),
                          // Name
                          _buildNameWidget(),
                          SizedBox(height: 20),
                          // Activity Stats
                          _buildActivityStats(
                              totalTasks, completedTasks.length),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Task Statistics Cards
              SliverPadding(
                padding: EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 15),
                      _buildActivityCards(todos),
                    ],
                  ),
                ),
              ),

              // Recent Activity
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 15),
                      _buildRecentActivity(todos),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage:
                _profileImage != null ? FileImage(_profileImage!) : null,
            child: _profileImage == null
                ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                : null,
          ),
        ),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            padding: EdgeInsets.all(8),
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
            child: Icon(Icons.camera_alt, size: 20, color: Colors.blue[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildNameWidget() {
    return _isEditingName
        ? Container(
            width: 200,
            child: TextField(
              controller: _nameController,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.check, color: Colors.white),
                  onPressed: () => setState(() => _isEditingName = false),
                ),
              ),
            ),
          )
        : GestureDetector(
            onTap: () => setState(() => _isEditingName = true),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _nameController.text,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.edit,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
              ],
            ),
          );
  }

  Widget _buildActivityStats(int totalTasks, int completedTasks) {
    final completionRate =
        totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Tasks', totalTasks.toString()),
          _buildStatItem('Completed', '$completedTasks'),
          _buildStatItem(
              'Success Rate', '${completionRate.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCards(List<TodoItem> todos) {
    final completedTasks = todos.where((todo) => todo.isCompleted).toList();
    final pendingTasks = _getPendingTasks(todos);
    final overdueTasks = _getOverdueTasks(todos);

    return Container(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActivityCard(
            'Completed',
            completedTasks.length.toString(),
            Icons.check_circle_outline,
            Colors.green[700]!,
            () => _showTaskDetailsBottomSheet('Completed', completedTasks),
          ),
          _buildActivityCard(
            'Pending',
            pendingTasks.length.toString(),
            Icons.pending_actions,
            Colors.orange[700]!,
            () => _showTaskDetailsBottomSheet('Pending', pendingTasks),
          ),
          _buildActivityCard(
            'Overdue',
            overdueTasks.length.toString(),
            Icons.warning_outlined,
            Colors.red[700]!,
            () => _showTaskDetailsBottomSheet('Overdue', overdueTasks),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    String title,
    String count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 15),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                Spacer(),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<TodoItem> todos) {
    final recentTodos = todos.where((todo) => !todo.isCompleted).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: recentTodos.take(5).length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final todo = recentTodos[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.list_alt, color: Colors.blue[600]),
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Due: ${DateFormat('MMM dd, yyyy').format(todo.dueDate)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          );
        },
      ),
    );
  }

  // Helper methods for task filtering remain the same...
  List<TodoItem> _getOverdueTasks(List<TodoItem> todos) {
    return todos.where((task) => _isTaskOverdue(task)).toList();
  }

  bool _isTaskOverdue(TodoItem task) {
    if (task.isCompleted) return false;
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

  void _showTaskDetailsBottomSheet(String title, List<TodoItem> tasks) {
    // Existing bottom sheet implementation...
  }
}
