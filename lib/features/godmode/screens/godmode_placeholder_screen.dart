import 'package:flutter/material.dart';

/// Placeholder screen for the GodMode admin dashboard.
/// Phase 22 replaces this with the full dashboard UI.
class GodModePlaceholderScreen extends StatelessWidget {
  const GodModePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GodMode')),
      body: const Center(
        child: Text('GodMode Dashboard — Coming in Phase 22'),
      ),
    );
  }
}
