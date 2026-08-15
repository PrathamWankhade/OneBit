import 'package:onebit/core/result/result.dart';

/// Repository contract for the mesh radio session.
///
/// A "session" is the local node's connection to the mesh: it owns the
/// mesh's shared secrets, session state and lifetime. This phase declares
/// the contract; the BLE mesh phase implements it against the native core.
abstract interface class MeshSessionRepository {
  /// Opens (or resumes) the local mesh session.
  Future<Result<void>> open();

  /// Closes the session and releases native resources.
  Future<Result<void>> close();

  /// True when the session is open and the radio is attached.
  bool get isOpen;
}
