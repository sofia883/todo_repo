import 'package:flutter/material.dart';
import 'package:to_do_app/screens/home.dart';
import 'package:to_do_app/screens/welcome_page.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'data/todo_service.dart';
import 'screens/profile_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Timer for checking overdue tasks
Timer? overdueCheckTimer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezones
  tz.initializeTimeZones();

  // Initialize notifications
  await initializeNotifications();

  // Start checking for overdue tasks
  startOverdueTaskCheck();

  runApp(MyApp());
}

void startOverdueTaskCheck() {
  // Check every minute for overdue tasks
  overdueCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
    checkForOverdueTasks();
  });
}

Future<void> checkForOverdueTasks() async {
  final todoStorage = TodoStorage(); // Your todo storage instance
  final todos = await todoStorage.getTodosStream().first;

  final now = DateTime.now();

  for (var todo in todos) {
    if (!todo.isCompleted) {
      final taskDueDateTime = DateTime(
        todo.dueDate.year,
        todo.dueDate.month,
        todo.dueDate.day,
        todo.dueTime?.hour ?? 23,
        todo.dueTime?.minute ?? 59,
      );

      // Check if task just became overdue (within the last minute)
      if (taskDueDateTime.isBefore(now) &&
          taskDueDateTime.isAfter(now.subtract(Duration(minutes: 1)))) {
        showOverdueNotification(todo);
      }
    }
  }
}

Future<void> showOverdueNotification(TodoItem todo) async {
  // Option 1: With default sound
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'overdue_tasks',
    'Overdue Tasks',
    channelDescription: 'Notifications for overdue tasks',
    importance: Importance.high,
    priority: Priority.high,
    color: Colors.red,
    enableVibration: true,
    // Using default sound instead of custom sound
    playSound: true,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    // Remove custom sound reference
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    todo.hashCode,
    'Task Overdue!',
    'The task "${todo.title}" is now overdue',
    notificationDetails,
  );
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) async {
      // Navigate to the task when notification is tapped
      // You'll need to implement this navigation logic
      print('Notification clicked: ${details.payload}');
    },
  );

  // Request iOS permissions
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    overdueCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: WelcomePage(),
      routes: {
        '/login': (context) => WelcomePage(),
        '/home': (context) => TodoList(),
      },
    );
  }
}
