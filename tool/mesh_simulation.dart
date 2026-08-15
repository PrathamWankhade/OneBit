import 'package:onebit/features/mesh/simulation/simulation_scenarios.dart';

/// Headless mesh simulation runner.
///
/// Prints a pass/fail report for every scenario:
///
///     flutter test tool/mesh_simulation.dart
Future<void> main() async {
  final scenarios = <String, Future<ScenarioRun> Function()>{
    'two-node deliver': MeshScenarios.twoNodeDeliver,
    'five-node chain': MeshScenarios.fiveNodeChain,
    'ten-node ring': MeshScenarios.tenNodeRing,
    'twenty-node lattice': MeshScenarios.twentyNodeLattice,
    'fifty-node churn': MeshScenarios.fiftyNodeChurn,
    'node join discovered': MeshScenarios.nodeJoinLearned,
    'node leave dissolves': MeshScenarios.nodeLeaveDissolves,
    'route failure repairs': MeshScenarios.routeFailureRepairs,
    'relay failure survives': MeshScenarios.relayFailureSurvives,
    'network partition isolates': MeshScenarios.networkPartitionIsolates,
    'topology recovery reconnects': MeshScenarios.topologyRecoveryReconnects,
  };

  var totalPassed = 0;
  var totalFailed = 0;

  for (final entry in scenarios.entries) {
    // ignore: avoid_print
    print('== ${entry.key} ==');
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
  }

  // ignore: avoid_print
  print('-----------------------------');
  // ignore: avoid_print
  print('total: $totalPassed passed, $totalFailed failed');
  if (totalFailed > 0) {
    throw StateError('$totalFailed scenario checks failed');
  }
}
