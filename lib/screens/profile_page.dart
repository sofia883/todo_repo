import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:to_do_app/data/auth_service.dart';

class ProfilePage extends StatelessWidget {
  final List<TodoItem> todos;
  ProfilePage({Key? key, required this.todos}) : super(key: key);

  final TodoStorage _todoStorage = TodoStorage();

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

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final todos = snapshot.data ?? [];
          final completedTasks =
              todos.where((todo) => todo.isCompleted).toList();

          // Get start of today
          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);

          // Get overdue tasks (tasks due before today and not completed)
          final overdueTasks = todos
              .where((todo) =>
                  !todo.isCompleted && todo.dueDate.isBefore(startOfToday))
              .toList()
            ..sort(
                (a, b) => b.dueDate.compareTo(a.dueDate)); // Most recent first

          final upcomingTasks = todos
              .where((todo) =>
                  !todo.isCompleted && !todo.dueDate.isBefore(startOfToday))
              .toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue[100],
                          child:
                              Icon(Icons.person, size: 40, color: Colors.blue),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Progress Statistics
                SizedBox(height: 24),
                Row(
                  children: [
                    _buildStatCard(
                      context,
                      'Completed',
                      '${completedTasks.length}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    SizedBox(width: 16),
                    _buildStatCard(
                      context,
                      'Upcoming',
                      '${upcomingTasks.length}',
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    SizedBox(width: 16),
                    _buildStatCard(
                      context,
                      'Past Due',
                      '${overdueTasks.length}',
                      Icons.warning,
                      Colors.red,
                    ),
                  ],
                ),
                if (overdueTasks.isNotEmpty) ...[
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Past Due Tasks',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Due dates passed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],

                // Task Progress Timeline
                SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        CircularPercentIndicator(
                          radius: 35.0,
                          lineWidth: 10.0,
                          percent: todos.isEmpty
                              ? 0
                              : completedTasks.length / todos.length,
                          center: Text(
                            '${((completedTasks.length / todos.length) * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16.0),
                          ),
                          progressColor: Colors.blue,
                          backgroundColor: Colors.grey[200]!,
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${((completedTasks.length / todos.length) * 100).toStringAsFixed(1)}% Complete',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Overdue Tasks Grid
                if (overdueTasks.isNotEmpty) ...[
                  SizedBox(height: 24),
                  Text(
                    'Overdue Tasks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                ],

                // Settings Section (remaining code stays the same)
                SizedBox(height: 32),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Card(
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
                      Divider(height: 1),
                      _buildSettingsTile(
                        'Backup & Sync',
                        Icons.sync,
                        Colors.blue,
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

  // Existing helper methods remain the same
  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
