import 'package:flutter/material.dart';

class ArticleScreen extends StatelessWidget {
  final int id;
  const ArticleScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Makale')),
      body: Center(child: Text('Makale ID: $id')),
    );
  }
}
