// Minimal widget smoke test: the app shell builds without crashing.
//
// Deliberately does NOT pump past the first frame — FoundationsScreen
// kicks off real network calls (Supabase auth, server_now()) that this
// test has no business waiting on. That real end-to-end path is what
// test/server/phase0_smoke_test.dart is for.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manhunt_sg/main.dart';

void main() {
  testWidgets('app shell renders the Phase 0 screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ManhuntApp()));

    expect(find.text('Manhunt SG — Phase 0'), findsOneWidget);
  });
}
