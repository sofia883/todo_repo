import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:to_do_app/data/todo_service.dart';

class TodoAlarmService {
  static const String NOTIFICATION_PORT_NAME = "todo_notification_port";
  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    final receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
      receivePort.sendPort,
      NOTIFICATION_PORT_NAME,
    );
  }

  static Future<void> scheduleTaskCheck(TodoItem todo) async {
    if (todo.isCompleted) return;

    // Save task data to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final taskData = {
      'id': todo.id,
      'title': todo.title,
      'description': todo.description,
      'dueDate': todo.dueDate.toIso8601String(),
      'dueTime': todo.dueTime != null 
          ? {'hour': todo.dueTime!.hour, 'minute': todo.dueTime!.minute}
          : null,
    };
    
    await prefs.setString('task_${todo.id}', jsonEncode(taskData));

    // Calculate exact due time
    final dueDateTime = todo.dueTime != null
        ? DateTime(
            todo.dueDate.year,
            todo.dueDate.month,
            todo.dueDate.day,
            todo.dueTime!.hour,
            todo.dueTime!.minute,
          )
        : DateTime(
            todo.dueDate.year,
            todo.dueDate.month,
            todo.dueDate.day,
            23,
            59,
          );

    // Schedule alarm at exact time
    await AndroidAlarmManager.oneShot(
      Duration(milliseconds: dueDateTime.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch),
      todo.id.hashCode, // Alarm ID
      checkAndNotifyOverdue,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: taskData, // Pass the Map directly
    );
  }

  static Future<void> cancelTaskAlarm(String todoId) async {
    await AndroidAlarmManager.cancel(todoId.hashCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('task_${todoId}');
  }

  @pragma('vm:entry-point')
  static Future<void> checkAndNotifyOverdue(int id, Map<String, dynamic> taskData) async {
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(NOTIFICATION_PORT_NAME);

    final dueDate = DateTime.parse(taskData['dueDate']);
    final now = DateTime.now();

    if (now.isAfter(dueDate)) {
      const androidDetails = AndroidNotificationDetails(
        'overdue_tasks',
        'Overdue Tasks',
        channelDescription: 'Notifications for overdue tasks',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        'Task Overdue!',
        'The task "${taskData['title']}" is now overdue',
        notificationDetails,
      );
    }
  }
}