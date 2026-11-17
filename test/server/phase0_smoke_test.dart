// Runs against the hosted project — no widget tree, no emulator, no mocks.
// First brick of the `test/server/` suite described in the plan's
// Verification section: real auth, real RLS, real RPC.
//
// NOTE: the plan describes this as "plain `dart test`". In practice, a
// standalone `test` package dependency conflicts with the `analyzer`
// version Flutter's own SDK-pinned `flutter_test`/`test_api` requires
// inside a Flutter package (drift_dev needs analyzer >=10, flutter_test's
// pinned test_api forces analyzer <10). `flutter_test` re-exports the same
// test()/expect() API from package:test, so this file is identical either
// way — only the invocation differs:
//   flutter test test/server/phase0_smoke_test.dart
//
// Uses the plain `supabase` (non-Flutter) client since this suite has no
// use for Flutter bindings — same reasoning as the plan's "no Flutter
// widget tree needed for this suite".

import 'package:flutter_test/flutter_test.dart';
import 'package:manhunt_sg/config/env.dart';
import 'package:supabase/supabase.dart';

void main() {
  test('anonymous sign-in + server_now() round trip', () async {
    final client = SupabaseClient(Env.supabaseUrl, Env.supabasePublishableKey);

    final authResponse = await client.auth.signInAnonymously();
    addTearDown(client.dispose);
    expect(authResponse.user, isNotNull, reason: 'anonymous sign-in should return a user');
    expect(authResponse.session, isNotNull);

    final sentAt = DateTime.now().toUtc();
    final response = await client.rpc('server_now');
    final receivedAt = DateTime.now().toUtc();

    final serverTime = DateTime.parse(response as String).toUtc();
    final rtt = receivedAt.difference(sentAt);

    expect(rtt.inSeconds, lessThan(5), reason: 'RPC round trip should be fast');
    // The server's clock should be within a generous window of "now" as
    // seen from both sides of the round trip — this is a sanity check on
    // the pipe, not a precision claim.
    expect(serverTime.isAfter(sentAt.subtract(const Duration(seconds: 10))), isTrue);
    expect(serverTime.isBefore(receivedAt.add(const Duration(seconds: 10))), isTrue);
  });
}
