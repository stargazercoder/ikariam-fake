import 'package:flutter/material.dart';

/// Placeholder create-profile screen.
///
/// The real profile creation form is implemented in Plan 01-03.
/// This stub is required so GoRouter has a valid /create-profile destination.
class CreateProfileScreen extends StatelessWidget {
  const CreateProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Profile')),
      body: const Center(
        child: Text(
          'Profile creation — coming in Plan 01-03',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
