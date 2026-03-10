import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor for the Supabase client.
/// This is NOT a Riverpod provider — it is a global getter used project-wide
/// to avoid importing Supabase.instance.client directly in every file.
SupabaseClient get supabaseClient => Supabase.instance.client;
