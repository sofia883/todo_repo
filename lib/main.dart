import 'package:flutter/material.dart';
import 'package:to_do_app/screens/home.dart';
import 'package:to_do_app/screens/welcome_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: WelcomePage(), // Default to the login screen
      routes: {
        '/login': (context) => WelcomePage(),
        '/home': (context) => TodoList(),
      },
    );
  }
}
