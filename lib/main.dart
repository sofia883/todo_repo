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
import 'package:workmanager/workmanager.dart';
import 'package:to_do_app/data/todo_notification_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
 
  
  runApp(MyApp());
}
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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