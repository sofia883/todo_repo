import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/data/todo_service.dart';
import 'package:to_do_app/screens/home.dart';
import 'package:to_do_app/screens/login_page.dart';
import 'package:to_do_app/screens/welcome_page.dart';
import 'package:to_do_app/data/todo_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';

// Initialize notifications and run app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await HybridStorageService().initialize();
  // Enable offline persistence
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // Ensure Flutter bindings are initialized

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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          }
          if (snapshot.hasData) {
            return WelcomePage();
          }
          return LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => LoginPage(),
        '/welcome': (context) => WelcomePage(),
        '/register': (context) => SignupPage(),
        '/home': (context) => TodoList(),
      },
    );
  }
}
