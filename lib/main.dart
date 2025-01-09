import 'package:flutter/material.dart';
import 'package:to_do_app/pages/home.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
    const MyApp({Key? key}) : super(key: key); // Add the 'key' parameter

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Lists App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFFCE4EC),
      ),
      home: const TodoList(),
    );
  }
}
