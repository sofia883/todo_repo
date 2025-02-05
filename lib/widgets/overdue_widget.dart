import 'package:to_do_app/common_imports.dart';

class OverdueTasksHandler {
  // Helper method to check if a task is overdue
  static bool isTaskOverdue(ScheduleTask todo) {
    if (todo.isCompleted) return false;

    final now = DateTime.now();
    final dueDateTime = DateTime(
      todo.dueDate.year,
      todo.dueDate.month,
      todo.dueDate.day,
      todo.dueTime?.hour ?? 23,
      todo.dueTime?.minute ?? 59,
    );

    return dueDateTime.isBefore(now);
  }

  // Get list of overdue tasks
  static List<ScheduleTask> getOverdueTasks(List<ScheduleTask> todos) {
    return todos.where((task) => isTaskOverdue(task)).toList();
  }

  // Check and update tasks status
  static bool checkAndUpdateTasksStatus(List<ScheduleTask> todos) {
    final now = DateTime.now();
    bool needsUpdate = false;

    for (var todo in todos) {
      final dueDateTime = DateTime(
        todo.dueDate.year,
        todo.dueDate.month,
        todo.dueDate.day,
        todo.dueTime?.hour ?? 23,
        todo.dueTime?.minute ?? 59,
      );

      // Check if task just became overdue
      if (!todo.isCompleted && dueDateTime.isBefore(now) && !todo.isOverdue) {
        todo.isOverdue = true;
        needsUpdate = true;
      }
    }

    return needsUpdate;
  }

  // Build overdue task item widget
  static Widget buildOverdueTaskItem(
    ScheduleTask todo,
    Color categoryColor,
    Function(ScheduleTask) onReschedule,
    Function(String) onDelete,
    Function(String, bool) onToggleComplete,
  ) {
    return Dismissible(
      key: Key(todo.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(todo.id),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Checkbox(
            value: todo.isCompleted,
            activeColor: categoryColor,
            onChanged: (bool? value) {
              if (value != null) {
                onToggleComplete(todo.id, value);
              }
            },
          ),
          title: Text(
            todo.title,
            style: GoogleFonts.inter(
              fontSize: 16,
              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
              color: todo.isCompleted ? Colors.grey : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.description?.isNotEmpty ?? false)
                Text(
                  todo.description!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.red[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Overdue',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.red[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => onReschedule(todo),
            color: categoryColor,
          ),
        ),
      ),
    );
  }
}

// You'll need this class definition if not already defined elsewhere
class ScheduleTask {
  final String id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final TimeOfDay? dueTime;
  bool isCompleted;
  bool isOverdue;

  ScheduleTask({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.isOverdue = false,
  });
}