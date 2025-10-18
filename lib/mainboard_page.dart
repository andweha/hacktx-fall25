import 'package:flutter/material.dart';

class MainBoardPage extends StatelessWidget {
  const MainBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main Board')),
      body: const Center(
        child: Text('This is the Main Board Page'),
      ),
    );
  }
}
