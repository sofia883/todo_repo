import 'dart:async';
import 'package:flutter/material.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:to_do_app/screens/home.dart';
import 'package:to_do_app/screens/welcome_page.dart';
import 'package:to_do_app/data/todo_notification_service.dart';

// Initialize notifications and run app
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Run the app
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();

    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Start periodic task check
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    // Cancel timer when app is disposed
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground, restart periodic check
        _startPeriodicCheck();
        break;
      case AppLifecycleState.paused:
        // App went to background, cancel timer to save resources
        _periodicTimer?.cancel();
        break;
      default:
        break;
    }
  }

  void _startPeriodicCheck() {
    // Cancel existing timer if any
    _periodicTimer?.cancel();

    // Check immediately when starting
    TodoStorage().checkOverdueTasks();

    // Set up periodic check every minute
    _periodicTimer =
        Timer.periodic(const Duration(minutes: 1), (Timer t) async {
      await TodoStorage().checkOverdueTasks();
    });
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
