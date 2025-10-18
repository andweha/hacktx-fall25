import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'mainboard_page.dart';
import 'feed_page.dart';
import 'onboarding_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const OnboardingPage(), // start with onboarding
    );
  }
}
