import 'package:flutter/material.dart';

class DebugScreen extends StatelessWidget {
  final String debugData;

  DebugScreen({required this.debugData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Information'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          debugData,
          style: const TextStyle(fontSize: 16.0),
        ),
      ),
    );
  }
}

