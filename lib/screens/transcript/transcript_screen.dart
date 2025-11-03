import 'package:flutter/material.dart';

class TranscriptScreen extends StatelessWidget {
  final String bookId;
  const TranscriptScreen({required this.bookId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transcript')),
      body: const Center(child: Text('Transcript placeholder')),
    );
  }
}
