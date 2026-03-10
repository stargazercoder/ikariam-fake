import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../features/profile/data/profile_repository.dart';
import '../../../features/profile/providers/profile_provider.dart';
import '../../../features/profile/widgets/avatar_picker.dart';
import '../../../shared/widgets/loading_overlay.dart';

/// Profile creation screen — mandatory gate between sign-up and gameplay.
///
/// Authenticated users who have not yet set a display name are redirected here
/// by the GoRouter guard.  There is no back button — the only escape routes
/// are completing the form (→ /city) or signing out.
///
/// On submit the screen calls [ProfileRepository.updateProfile] directly,
/// which is the intentional exception to the "Edge Functions only" rule (the
/// profiles table uses player-preferences RLS, not game-state RLS).
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  int _selectedAvatarId = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a display name';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value)) {
      return '3–20 characters, letters, numbers, and underscore only';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            displayName: _nameController.text.trim(),
            avatarId: _selectedAvatarId,
          );

      // Refresh profile so GoRouter guard sees the completed profile.
      await ref.read(profileProvider.notifier).refresh();

      if (mounted) {
        context.go('/city');
      }
    } on DisplayNameTakenException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That display name is already taken'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create Your Profile',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose your avatar and display name to enter the game',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Choose your avatar',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          AvatarPicker(
                            selectedAvatarId: _selectedAvatarId,
                            onAvatarSelected: (id) {
                              setState(() => _selectedAvatarId = id);
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Display Name',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            validator: _validateDisplayName,
                            maxLength: 20,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              hintText: 'e.g. ThunderLord_88',
                              helperText:
                                  '3–20 characters, letters, numbers, and underscore',
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: const Text('Enter the Game'),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _isLoading ? null : _signOut,
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
