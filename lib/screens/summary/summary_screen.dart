import 'package:flutter/material.dart';

class SummaryScreen extends StatelessWidget {
  final String bookId;
  const SummaryScreen({required this.bookId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: const Center(child: Text('Summary placeholder')),
    );
  }
}
