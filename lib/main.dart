import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'data/local/database.dart';
import 'data/supabase/client.dart';
import 'game/clock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSupabase.initialize();
  runApp(const ProviderScope(child: ManhuntApp()));
}

class ManhuntApp extends StatelessWidget {
  const ManhuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manhunt SG',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const FoundationsScreen(),
    );
  }
}

/// Phase 0 scaffolding screen: proves the whole foundation works end to end
/// on a real device before any game logic exists — anonymous auth, the
/// `server_now()` RPC round trip (and the clock offset it produces), and a
/// write/read round trip through the local offline queue.
class FoundationsScreen extends StatefulWidget {
  const FoundationsScreen({super.key});

  @override
  State<FoundationsScreen> createState() => _FoundationsScreenState();
}

class _FoundationsScreenState extends State<FoundationsScreen> {
  final _db = AppDatabase();
  String _status = 'Starting...';

  @override
  void initState() {
    super.initState();
    _runFoundationsCheck();
  }

  Future<void> _runFoundationsCheck() async {
    final lines = <String>[];

    try {
      await AppSupabase.ensureSignedIn();
      final userId = AppSupabase.client.auth.currentUser?.id;
      lines.add('✓ Signed in anonymously\n  auth.uid() = $userId');
    } catch (e) {
      lines.add('✗ Anonymous sign-in failed:\n  $e');
      setState(() => _status = lines.join('\n\n'));
      return;
    }

    try {
      final offset = await GameClock.measureOffset();
      lines.add(
        '✓ server_now() round trip ok\n'
        '  measured offset = ${offset.inMilliseconds} ms\n'
        '  GameClock.now() = ${GameClock.now()}',
      );
    } catch (e) {
      lines.add('✗ server_now() RPC failed:\n  $e');
    }

    try {
      final id = const Uuid().v4();
      await _db.into(_db.pendingActions).insert(
        PendingActionsCompanion.insert(
          clientActionId: id,
          kind: 'phase0_smoke',
          payload: '{}',
        ),
      );
      final row = await (_db.select(_db.pendingActions)
            ..where((t) => t.clientActionId.equals(id)))
          .getSingle();
      lines.add('✓ Drift queue write/read ok\n  row kind = ${row.kind}');
    } catch (e) {
      lines.add('✗ Drift queue check failed:\n  $e');
    }

    setState(() => _status = lines.join('\n\n'));
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manhunt SG — Phase 0')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(_status, style: const TextStyle(fontFamily: 'monospace')),
        ),
      ),
    );
  }
}
