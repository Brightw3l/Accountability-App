import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // make sure this file exists

void main() {
  runApp(const AchievrApp());
}

class AchievrApp extends StatelessWidget {
  const AchievrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Achievr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // start screen of your app
    );
  }
}
