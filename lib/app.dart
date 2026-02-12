import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // or whatever file HomeScreen is in

class AchievrApp extends StatelessWidget {
  const AchievrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
