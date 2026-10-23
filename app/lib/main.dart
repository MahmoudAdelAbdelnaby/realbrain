import 'package:flutter/material.dart';

void main() => runApp(const ReelbrainApp());

class ReelbrainApp extends StatelessWidget {
  const ReelbrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reelbrain',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Reelbrain')),
      ),
    );
  }
}
