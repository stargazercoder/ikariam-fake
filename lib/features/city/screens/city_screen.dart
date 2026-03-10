import 'package:flutter/material.dart';

/// Placeholder city screen.
///
/// Game content is added in Phase 2.  For now this is a bare scaffold so
/// GoRouter has a valid destination after login.
class CityScreen extends StatelessWidget {
  const CityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My City')),
      body: const Center(
        child: Text(
          'City screen — coming in Phase 2',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
