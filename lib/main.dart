import 'package:flutter/material.dart';
import 'home.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Lists App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Color(0xFFFCE4EC),
      ),
      home: TodoList(),
    );
  }
}
