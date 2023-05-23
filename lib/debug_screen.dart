import 'package:flutter/material.dart';

class DebugScreen extends StatelessWidget {
  final Map<String, dynamic> debugData;

  DebugScreen({Key? key, required this.debugData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Information'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: debugData.keys.length,
          itemBuilder: (context, index) {
            String key = debugData.keys.elementAt(index);
            return ListTile(
              title: Text('$key: ${debugData[key]}'),
            );
          },
        ),
      ),
    );
  }
}
