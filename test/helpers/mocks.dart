// Mock classes for unit testing.
//
// These stubs are used across the test suite to isolate units under test
// from real Supabase/GoRouter implementations.

import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ikariam/features/auth/data/auth_repository.dart';
import 'package:ikariam/features/profile/data/profile_repository.dart';

/// Mock for [SupabaseClient]. Use in tests that call [supabaseClient].
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Mock for [GoRouter]. Use in tests that verify navigation calls.
class MockGoRouter extends Mock implements GoRouter {}

/// Mock for [AuthRepository]. Use in widget tests that trigger sign-in/sign-up.
class MockAuthRepository extends Mock implements AuthRepository {}

/// Mock for [ProfileRepository]. Use in widget tests that read/update profiles.
class MockProfileRepository extends Mock implements ProfileRepository {}
