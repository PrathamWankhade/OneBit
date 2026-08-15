import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/mesh/simulation/simulation_scenarios.dart';

void main() {
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

  for (final entry in scenarios.entries) {
    test(entry.key, () async {
      final run = await entry.value();
      for (final check in run.checks.entries) {
        expect(check.value, isTrue, reason: '${entry.key}: ${check.key}');
      }
    });
  }
}
