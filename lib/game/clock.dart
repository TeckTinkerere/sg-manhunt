import '../data/supabase/client.dart';

/// The client's mirror of server time. It never decides anything — every
/// countdown rendered from [offset] is display-only; cooldowns, reveals and
/// match completion are computed on the server (see plan: non-negotiable
/// invariant #4 and the `game_elapsed_ms`/`game_wall_at` SQL functions
/// added in Phase 3).
///
/// The offset is measured by calling the `server_now()` RPC a handful of
/// times and keeping the sample with the smallest round-trip time, on the
/// assumption that sample had the least queueing/jitter and so the best
/// estimate of one-way latency (~ rtt / 2).
class GameClock {
  GameClock._();

  static Duration? _offset;

  /// Server time right now, best estimate. Falls back to local device time
  /// if [measureOffset] hasn't been called yet (or failed) — a fallback
  /// that only ever affects *display*, never a server-authoritative rule.
  static DateTime now() {
    final offset = _offset;
    final local = DateTime.now().toUtc();
    return offset == null ? local : local.add(offset);
  }

  /// Measures the client/server clock offset via `sampleCount` round trips
  /// to the `server_now()` RPC, keeping the minimum-RTT sample.
  static Future<Duration> measureOffset({int sampleCount = 5}) async {
    Duration? best;
    Duration? bestRtt;

    for (var i = 0; i < sampleCount; i++) {
      final sentAt = DateTime.now().toUtc();
      final response = await AppSupabase.client.rpc('server_now');
      final receivedAt = DateTime.now().toUtc();

      final rtt = receivedAt.difference(sentAt);
      final serverTime = DateTime.parse(response as String).toUtc();

      // Best estimate of "now" on the server at receipt time: the server
      // timestamp plus half the round-trip (assumes symmetric latency).
      final estimatedServerNowAtReceipt = serverTime.add(rtt ~/ 2);
      final candidateOffset = estimatedServerNowAtReceipt.difference(receivedAt);

      if (bestRtt == null || rtt < bestRtt) {
        bestRtt = rtt;
        best = candidateOffset;
      }
    }

    final offset = best ?? Duration.zero;
    _offset = offset;
    return offset;
  }
}
