import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:to_do_app/data/todo_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      print('Initializing notification service...');
      tz.initializeTimeZones();

      // Use ic_launcher instead of custom icon
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          print('Notification received: ${details.payload}');
        },
      );

      // Create the notification channel
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'todo_notifications',
        'Todo Notifications',
        importance: Importance.max,
        playSound: true,
        showBadge: true,
        enableLights: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }Future<void> scheduleTodoNotification(TodoItem todo) async {
  try {
    if (todo.dueTime == null) {
      print('No due time set for todo: ${todo.title}');
      return;
    }

    final DateTime dueDateTime = DateTime(
      todo.dueDate.year,
      todo.dueDate.month,
      todo.dueDate.day,
      todo.dueTime!.hour,
      todo.dueTime!.minute,
    );

    print('Scheduling notification for todo: ${todo.title}');
    print('Due date time: $dueDateTime');

    // For overdue tasks, show notification immediately
    if (dueDateTime.isBefore(DateTime.now())) {
      final androidDetails = AndroidNotificationDetails(
        'todo_notifications',
        'Todo Notifications',
        channelDescription: 'Notifications for todo tasks',
        importance: Importance.max,
        priority: Priority.high,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      );

      await _notifications.show(
        '${todo.id}_overdue'.hashCode,
        '❗ Task Overdue',
        '${todo.title} is now overdue',
        notificationDetails,
        payload: todo.id,
      );
      return;
    }

    // For future tasks, schedule notifications as before
    final DateTime reminderTime =
        dueDateTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: '${todo.id}_reminder'.hashCode,
        title: '⏰ Upcoming Task',
        body: '${todo.title} is due in 15 minutes',
        scheduledDate: reminderTime,
        payload: todo.id,
      );
    }

    await _scheduleNotification(
      id: '${todo.id}_overdue'.hashCode,
      title: '❗ Task Overdue',
      body: '${todo.title} is now overdue',
      scheduledDate: dueDateTime,
      payload: todo.id,
    );
  } catch (e) {
    print('Error scheduling notification for todo ${todo.title}: $e');
  }
}Future<void> _scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
  String? payload,
}) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'todo_notifications',
      'Todo Notifications',
      channelDescription: 'Notifications for todo tasks',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableLights: true,
      enableVibration: true,
      channelShowBadge: true,
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);
    print('Scheduling notification for: $scheduledTime');
    print('Current time: ${DateTime.now()}');

    // Only schedule the actual notification
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    print('Notification scheduled successfully for ID: $id');
  } catch (e) {
    print('Error scheduling notification: $e');
    print('Stack trace: ${StackTrace.current}');
  }
}

  Future<void> cancelTodoNotifications(String todoId) async {
    try {
      await _notifications.cancel('${todoId}_reminder'.hashCode);
      await _notifications.cancel('${todoId}_overdue'.hashCode);
      print('Notifications cancelled for todo: $todoId');
    } catch (e) {
      print('Error cancelling notifications: $e');
    }
  }
}
