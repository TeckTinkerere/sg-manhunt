/// Supabase project configuration.
///
/// The anon key is safe to commit — Supabase's security model puts the
/// boundary at Row-Level Security, not at key secrecy (see the plan's
/// Architecture section). The service-role key is a different matter: it
/// bypasses RLS entirely and must NEVER appear in this repo or in the app.
///
/// Values are read at compile time via `--dart-define`, with the real
/// project's values as the default so a plain `flutter run` still works for
/// day-to-day development. Override for a different environment with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://atbucqazrqacwpimqkte.supabase.co',
  );

  /// Supabase's public client key. Historically called the "anon key"
  /// (still the term used throughout the plan and PRD); newer projects
  /// call it the "publishable key". Either way, it's safe to commit.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_LQRfsxTl56hgInlBiyuT5w_G1ceO40d',
  );
}
