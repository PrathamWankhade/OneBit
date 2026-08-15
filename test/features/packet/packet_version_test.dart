import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/packet/domain/packet_version.dart';
import 'package:onebit/features/packet/version/packet_version_manager.dart';

void main() {
  const current = PacketVersion.current;
  const other = PacketVersion.current;

  PacketVersion v(int transport, int major, int revision) =>
      PacketVersion(transport: transport, major: major, revision: revision);

  group('PacketVersion', () {
    test('identical versions relate as identical', () {
      expect(current.relationTo(other), PacketVersionRelation.identical);
    });

    test('revision deltas are tolerated', () {
      expect(
        current.relationTo(v(1, 1, 1)),
        PacketVersionRelation.newerRevision,
      );
      expect(
        current.relationTo(v(1, 1, -1)),
        PacketVersionRelation.olderRevision,
      );
    });

    test('major deltas are direction-aware', () {
      expect(current.relationTo(v(1, 2, 0)), PacketVersionRelation.newerMajor);
      expect(current.relationTo(v(1, 0, 0)), PacketVersionRelation.olderMajor);
    });

    test('transport mismatch always dominates', () {
      expect(
        current.relationTo(v(2, 1, 0)),
        PacketVersionRelation.transportMismatch,
      );
    });
  });

  group('PacketVersionManager', () {
    test('accepts identical and revision-delta frames', () {
      expect(PacketVersionManager.verify(current).accepted, isTrue);
      expect(PacketVersionManager.verify(v(1, 1, 3)).accepted, isTrue);
      expect(PacketVersionManager.verify(v(1, 1, 0)).accepted, isTrue);
    });

    test('accepts an older major (degraded semantics)', () {
      expect(PacketVersionManager.verify(v(1, 0, 2)).accepted, isTrue);
    });

    test('newer major needs the forward-compatibility bit', () {
      final newer = v(1, 2, 0);
      expect(PacketVersionManager.verify(newer).accepted, isFalse);
      expect(
        PacketVersionManager.verify(
          newer,
          compatibilityFlags: PacketVersionManager.compatibleForward,
        ).accepted,
        isTrue,
      );
    });

    test('transport mismatch is always dropped', () {
      final verdict = PacketVersionManager.verify(v(2, 1, 0));
      expect(verdict.accepted, isFalse);
      expect(verdict.relation, PacketVersionRelation.transportMismatch);
    });
  });
}
