import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isEditingName = false;
  bool _isEditingEmail = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current user details
    final currentUser = FirebaseAuth.instance.currentUser;
    _nameController.text = currentUser?.displayName ?? 'User Name';
    _emailController.text = currentUser?.email ?? 'user@example.com';
  }

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
        stream: FirebaseTaskService.getScheduledTasksStream(),
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
            // Modern Profile Header
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildProfileHeader(),
                  title: Text(
                    _nameController.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                ),
                backgroundColor: Colors.indigo, // Indigo app bar
              ),
              SliverToBoxAdapter(
                child: _buildProgressSection(widget.todos),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.indigo],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildProfileImage(),
          SizedBox(height: 10),
          _buildNameEmailSection(),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            image: _profileImage != null
                ? DecorationImage(
                    image: FileImage(_profileImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _profileImage == null
              ? Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.indigo[200],
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt,
                color: Colors.indigo,
              ),
              onPressed: _showImagePickerOptions,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameEmailSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Name Section
          _isEditingName
              ? TextField(
                  controller: _nameController,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.check, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isEditingName = false;
                          // TODO: Update display name in Firebase
                        });
                      },
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => setState(() => _isEditingName = true),
                  child: Text(
                    _nameController.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          SizedBox(height: 10),
          // Email Section
          Text(
            _emailController.text,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
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

  Widget _buildProgressSection(List<TodoItem> todos) {
    final completedTasks = todos.where((todo) => todo.isCompleted).toList();
    final pendingTasks = _getPendingTasks(todos);
    final overdueTasks = _getOverdueTasks(todos);

    // Calculate progress percentages
    final totalTasks = todos.length;
    final completionRate = totalTasks > 0
        ? (completedTasks.length / totalTasks * 100).toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildProgressCard(
            title: 'Completed Tasks',
            count: completedTasks.length.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
            onTap: () =>
                _showTaskDetailsBottomSheet('Completed Tasks', completedTasks),
          ),
          _buildProgressCard(
            title: 'Pending Tasks',
            count: pendingTasks.length.toString(),
            icon: Icons.pending_actions,
            color: Colors.orange,
            onTap: () =>
                _showTaskDetailsBottomSheet('Pending Tasks', pendingTasks),
          ),
          _buildProgressCard(
            title: 'Overdue Tasks',
            count: overdueTasks.length.toString(),
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            onTap: () =>
                _showTaskDetailsBottomSheet('Overdue Tasks', overdueTasks),
          ),
          _buildProgressCard(
            title: 'Progress',
            count: '$completionRate%',
            icon: Icons.timeline,
            color: Colors.blue,
            onTap: _showProgressDetailsBottomSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 40,
              ),
            ),
            SizedBox(height: 10),
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
                color: Colors.grey[700],
              ),
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
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Bottom sheet handle
              Container(
                width: 40,
                height: 5,
                margin: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        'Due: ${DateFormat('MMM dd, yyyy').format(task.dueDate)}',
                      ),
                      trailing: task.isCompleted
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : Icon(Icons.pending, color: Colors.orange),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProgressDetailsBottomSheet() {
    final todos = widget.todos;
    final totalTasks = todos.length;
    final completedTasks = todos.where((todo) => todo.isCompleted).length;
    final pendingTasks = _getPendingTasks(todos).length;
    final overdueTasks = _getOverdueTasks(todos).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Progress Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            _buildProgressDetailItem(
              'Total Tasks',
              totalTasks,
              Colors.blue,
            ),
            _buildProgressDetailItem(
              'Completed Tasks',
              completedTasks,
              Colors.green,
            ),
            _buildProgressDetailItem(
              'Pending Tasks',
              pendingTasks,
              Colors.orange,
            ),
            _buildProgressDetailItem(
              'Overdue Tasks',
              overdueTasks,
              Colors.red,
            ),
            SizedBox(height: 20),
            LinearProgressIndicator(
              value: totalTasks > 0 ? completedTasks / totalTasks : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 10,
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                '${(totalTasks > 0 ? completedTasks / totalTasks * 100 : 0).toStringAsFixed(1)}% Completed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDetailItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
}
