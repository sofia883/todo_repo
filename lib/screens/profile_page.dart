// First, let's modify the build method in TodoList to add the profile icon
// Update the build method in _TodoListState:

import 'package:flutter/material.dart';
import 'package:to_do_app/data/to_do_storage.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:to_do_app/data/auth_service.dart';

class ProfilePage extends StatelessWidget {
  final List<TodoItem> todos;

  ProfilePage({Key? key, required this.todos}) : super(key: key);

  final TodoStorage _todoStorage = TodoStorage();

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            'Profile',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
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
              final upcomingTasks = todos
                  .where((todo) => !todo.isCompleted)
                  .toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

              // Get overdue tasks
              final now = DateTime.now();
              final overdueTasks = upcomingTasks
                  .where((todo) => todo.dueDate.isBefore(now))
                  .toList();

              return SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ... (previous profile header code remains the same)

                      // Add Overdue Tasks Section
                      if (overdueTasks.isNotEmpty) ...[
                        SizedBox(height: 32),
                        Text(
                          'Overdue Tasks',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: overdueTasks.length,
                          itemBuilder: (context, index) {
                            final todo = overdueTasks[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(
                                  todo.title,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(todo.description),
                                    Text(
                                      'Due: ${_formatDate(todo.dueDate)}',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.check_circle_outline),
                                  onPressed: () async {
                                    await _todoStorage.updateTodoStatus(
                                        todo.id!, true);
                                  },
                                ),
                              ),
                            );
                          },
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
                            _buildSettingsTile(
                              'Sign Out',
                              Icons.logout,
                              Colors.red,
                              context,
                              onTap: () async {
                                await _authService.signOut();
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ));
            }));
  }

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
            // Default behavior if no onTap provided
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
