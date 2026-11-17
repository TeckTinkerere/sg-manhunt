import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';

/// Thin wrapper around the app's single Supabase client.
///
/// Non-negotiable invariant #4 (see plan): no game rule lives in the client.
/// This class — and everything under `lib/data/supabase/` — only ever
/// displays server state or sends intents (auth, RPC calls, Realtime
/// subscriptions). It must never encode a gameplay decision.
class AppSupabase {
  AppSupabase._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Call once at app startup, before anything else touches [client].
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  /// Ensures the device has an identity. `supabase_flutter` persists the
  /// session itself (SharedPreferences-backed), so this is a no-op after
  /// the first launch — verified by the Phase 0 smoke test.
  ///
  /// Anonymous users still get the `authenticated` Postgres role and a real
  /// `auth.uid()`, which is what every RLS policy in this app keys off.
  static Future<void> ensureSignedIn() async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }
}
