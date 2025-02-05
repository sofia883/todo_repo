import 'package:to_do_app/common_imports.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
class ScheduledTaskWidgets {
  final Color categoryColor;
  final Function(ScheduleTask) onReschedule;

  ScheduledTaskWidgets({
    required this.categoryColor,
    required this.onReschedule,
  });

  Widget buildTaskItem(ScheduleTask todo, BuildContext context, {bool isOverdue = false}) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Dismissible(
          key: Key(todo.id),
          direction: DismissDirection.endToStart,
          background: _buildDismissibleBackground(),
          confirmDismiss: (direction) => _confirmDismiss(context, todo),
          onDismissed: (direction) => _handleDelete(context, todo),
          child: Card(
            color: Colors.white,
            elevation: 3.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaskHeader(todo, setState, context, isOverdue),
                if (todo.isSubtasksExpanded && todo.subtasks.isNotEmpty)
                  _buildSubtasksList(todo, setState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDismissibleBackground() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  Future<bool> _confirmDismiss(BuildContext context, ScheduleTask todo) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleDelete(BuildContext context, ScheduleTask todo) async {
    try {
      await FirebaseTaskService.deleteScheduledTask(todo.id);
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              try {
                await FirebaseTaskService.addScheduledTask(todo);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to restore task'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTaskHeader(ScheduleTask todo, StateSetter setState, BuildContext context, bool isOverdue) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOverdue) _buildCheckbox(todo, setState, context),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(todo),
                if (todo.description.isNotEmpty) _buildDescription(todo),
                const SizedBox(height: 8),
                _buildDateTime(todo, isOverdue),
              ],
            ),
          ),
          if (isOverdue) _buildRescheduleButton(todo, context),
          if (todo.subtasks.isNotEmpty) _buildExpandButton(todo, setState),
        ],
      ),
    );
  }

  Widget _buildCheckbox(ScheduleTask todo, StateSetter setState, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: categoryColor.withOpacity(0.1),
      ),
      child: Transform.scale(
        scale: 1.2,
        child: Checkbox(
          value: todo.isCompleted,
          onChanged: (bool? newValue) => _handleTaskStatusChange(newValue, todo, setState, context),
          activeColor: categoryColor,
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _buildTitle(ScheduleTask todo) {
    return Text(
      todo.title.isEmpty ? 'Untitled Task' : todo.title,
      style: GoogleFonts.poppins(
        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
        color: todo.isCompleted ? Colors.grey[400] : Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDescription(ScheduleTask todo) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        todo.description,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey[600],
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDateTime(ScheduleTask todo, bool isOverdue) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 16,
          color: isOverdue ? Colors.red : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          todo.dueTime != null
              ? DateFormat('MMM d, h:mm a').format(DateTime(
                  todo.dueDate.year,
                  todo.dueDate.month,
                  todo.dueDate.day,
                  todo.dueTime!.hour,
                  todo.dueTime!.minute,
                ))
              : DateFormat('MMM d').format(todo.dueDate),
          style: TextStyle(
            fontSize: 13,
            color: isOverdue ? Colors.red : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRescheduleButton(ScheduleTask todo, BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.schedule, color: Colors.red),
      onPressed: () => onReschedule(todo),
      tooltip: 'Reschedule Task',
    );
  }

  Widget _buildExpandButton(ScheduleTask todo, StateSetter setState) {
    return IconButton(
      onPressed: () {
        setState(() {
          todo.isSubtasksExpanded = !todo.isSubtasksExpanded;
        });
      },
      icon: AnimatedRotation(
        duration: const Duration(milliseconds: 200),
        turns: todo.isSubtasksExpanded ? 0.5 : 0,
        child: Icon(
          Icons.keyboard_arrow_down,
          color: categoryColor,
        ),
      ),
    );
  }

  Widget _buildSubtasksList(ScheduleTask todo, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 16),
      child: Column(
        children: todo.subtasks.map((subtask) => _buildSubtaskItem(subtask, todo, setState)).toList(),
      ),
    );
  }

  Widget _buildSubtaskItem(ScheduleSubTask subtask, ScheduleTask todo, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: subtask.isCompleted,
              onChanged: (bool? value) => _handleSubtaskStatusChange(value, subtask, todo, setState),
              shape: const CircleBorder(),
              activeColor: categoryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtask.title,
              style: GoogleFonts.inter(
                decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                color: subtask.isCompleted ? Colors.grey[400] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTaskStatusChange(
    bool? newValue,
    ScheduleTask todo,
    StateSetter setState,
    BuildContext context,
  ) async {
    if (newValue == null) return;

    final shouldUpdate = await _showTaskCompletionDialog(todo, todo.isCompleted, context);
    if (!shouldUpdate) return;

    setState(() {
      todo.isCompleted = newValue;
      todo.completedAt = newValue ? DateTime.now() : null;
      for (var subtask in todo.subtasks) {
        subtask.isCompleted = newValue;
        subtask.completedAt = newValue ? DateTime.now() : null;
      }
    });

    try {
      await FirebaseTaskService.updateScheduledTask(todo);
    } catch (e) {
      setState(() {
        todo.isCompleted = !newValue;
        todo.completedAt = !newValue ? DateTime.now() : null;
        for (var subtask in todo.subtasks) {
          subtask.isCompleted = !newValue;
          subtask.completedAt = !newValue ? DateTime.now() : null;
        }
      });
    }
  }

  Future<void> _handleSubtaskStatusChange(
    bool? value,
    ScheduleSubTask subtask,
    ScheduleTask todo,
    StateSetter setState,
  ) async {
    if (value == null) return;
    setState(() {
      subtask.isCompleted = value;
      subtask.completedAt = value ? DateTime.now() : null;
      _updateMainTaskStatus(todo, setState);
    });
    try {
      await FirebaseTaskService.updateScheduledTask(todo);
    } catch (e) {
      // Handle error
    }
  }

  void _updateMainTaskStatus(ScheduleTask todo, StateSetter setState) {
    final allComplete = todo.subtasks.every((subtask) => subtask.isCompleted);
    if (todo.isCompleted != allComplete) {
      setState(() {
        todo.isCompleted = allComplete;
        todo.completedAt = allComplete ? DateTime.now() : null;
      });
    }
  }

  Future<bool> _showTaskCompletionDialog(
    ScheduleTask todo,
    bool isCurrentlyCompleted,
    BuildContext context,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(
          isCurrentlyCompleted ? 'Mark Task as Incomplete?' : 'Complete Task?',
          style: GoogleFonts.aBeeZee(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrentlyCompleted
                  ? 'Are you sure you want to mark this task as incomplete?'
                  : 'Are you sure you want to mark this task as complete?',
              style: GoogleFonts.aBeeZee(),
            ),
            const SizedBox(height: 12),
            Text(todo.title, style: GoogleFonts.aBeeZee()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.aBeeZee(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: categoryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isCurrentlyCompleted ? 'Mark Incomplete' : 'Complete',
              style: GoogleFonts.aBeeZee(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
}