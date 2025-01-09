// First, let's modify the build method in TodoList to add the profile icon
// Update the build method in _TodoListState:

import 'package:flutter/material.dart';
import 'package:to_do_app/services/todo_service.dart';

class ProfilePage extends StatelessWidget {
  final List<TodoItem> todos;

  const ProfilePage({Key? key, required this.todos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final completedTasks = todos.where((todo) => todo.isCompleted).toList();
    final upcomingTasks = todos.where((todo) => !todo.isCompleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final earliestDate = upcomingTasks.isNotEmpty ? upcomingTasks.first.dueDate : DateTime.now();
    final latestDate = upcomingTasks.isNotEmpty ? upcomingTasks.last.dueDate : DateTime.now();
    
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.person, size: 50, color: Colors.grey[400]),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Task Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Statistics Cards
            Row(
              children: [
                _buildStatCard(
                  context,
                  'Total Tasks',
                  todos.length.toString(),
                  Icons.assignment,
                  Colors.blue,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  context,
                  'Completed',
                  completedTasks.length.toString(),
                  Icons.task_alt,
                  Colors.green,
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard(
                  context,
                  'Pending',
                  upcomingTasks.length.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  context,
                  'Completion Rate',
                  '${(completedTasks.length / (todos.isEmpty ? 1 : todos.length) * 100).toStringAsFixed(1)}%',
                  Icons.analytics,
                  Colors.purple,
                ),
              ],
            ),

            // Timeline Section
            if (upcomingTasks.isNotEmpty) ...[
              SizedBox(height: 32),
              Text(
                'Task Timeline',
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
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimelineItem('First Task Due', earliestDate),
                      SizedBox(height: 16),
                      _buildTimelineItem('Last Task Due', latestDate),
                      SizedBox(height: 16),
                      Text(
                        'You have ${upcomingTasks.length} tasks to complete between these dates',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Settings Section
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
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

  Widget _buildTimelineItem(String label, DateTime date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          '${date.day}/${date.month}/${date.year}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, Color color, BuildContext context) {
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
      onTap: () {
        // Handle settings navigation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title settings coming soon')),
        );
      },
    );
  }
}