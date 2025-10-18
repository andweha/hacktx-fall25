import 'package:flutter/material.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends Feed')),
      body: const Center(
        child: Text('Updates about friends completing tasks'),
      ),
    );
  }
}
