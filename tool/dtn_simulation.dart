import 'package:onebit/features/dtn/simulation/dtn_scenarios.dart';

/// Headless DTN (store-and-forward) simulation runner.
///
/// Prints a pass/fail report for every scenario:
///
///     flutter test tool/dtn_simulation.dart
Future<void> main() async {
  final scenarios = <String, Future<DtnScenarioRun> Function()>{
    'offline node': DtnScenarios.offlineNode,
    'reconnect': DtnScenarios.reconnect,
    'large queue 1000 pending packets': DtnScenarios.largeQueue1000,
    'delayed delivery': DtnScenarios.delayedDelivery,
    'network partition & merge': DtnScenarios.networkPartitionAndMerge,
    'queue recovery (restart)': DtnScenarios.queueRecovery,
    'retry storm': DtnScenarios.retryStorm,
    'packet expiration': DtnScenarios.packetExpiration,
  };

  var totalPassed = 0;
  var totalFailed = 0;

  for (final entry in scenarios.entries) {
    // ignore: avoid_print
    print('== ${entry.key} ==');
    try {
      final run = await entry.value();
      for (final check in run.checks.entries) {
        final mark = check.value ? 'PASS' : 'FAIL';
        // ignore: avoid_print
        print('  [$mark] ${check.key}');
        if (check.value) {
          totalPassed++;
        } else {
          totalFailed++;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('  [ERROR] scenario threw: $e');
      totalFailed++;
    }
  }

  // ignore: avoid_print
  print('-----------------------------');
  // ignore: avoid_print
  print('total: $totalPassed passed, $totalFailed failed');
  if (totalFailed > 0) {
    throw StateError('$totalFailed scenario checks failed');
  }
}
