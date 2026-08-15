import 'dart:typed_data';

import 'package:onebit/core/errors/failure.dart';
import 'package:onebit/core/result/result.dart';

/// Contract for calling the native C++ core via FFI.
///
/// In later phases this exposes the radio-facing primitives (COBS framing,
/// packet codec, hash routines) as raw symbol calls. Dart obtains a
/// [DynamicLibrary] handle through `dart:ffi` and pins `extern` functions.
///
/// Phase 1 deliberately provides [FfiBridge] *without* a C++ core; features
/// that depend on it must degrade gracefully via [UnsupportedOperationFailure].
abstract interface class FfiBridge {
  /// True once the native library has been loaded and symbols resolved.
  bool get isAvailable;

  /// Machine name of the shared library, e.g. `libonebit_native.so`.
  String get libraryName;

  /// Invokes a native function that exchanges a raw byte payload.
  ///
  /// Returns a [Result] whose payload is the native response buffer. The
  /// concrete frame protocol is defined when the C++ side lands.
  Future<Result<Uint8List>> invoke(String symbol, Uint8List payload);
}

/// Stand-in [FfiBridge] for builds without the native core linked.
///
/// This is the *truthful* state of Phase 1: the C++ library is not built, so
/// every invocation resolves to an [UnsupportedOperationFailure] rather than
/// fabricating a result. Replaced by the real loader in the FFI phase.
final class UnavailableFfiBridge implements FfiBridge {
  const UnavailableFfiBridge();

  @override
  final bool isAvailable = false;

  @override
  String get libraryName => 'libonebit_native.so';

  @override
  Future<Result<Uint8List>> invoke(String symbol, Uint8List payload) async =>
      const Err(
        UnsupportedOperationFailure(
          feature: 'ffi-core',
          message: 'Native core is not linked in this build.',
        ),
      );
}
