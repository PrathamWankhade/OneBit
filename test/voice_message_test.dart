import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebit/features/conversations/presentation/voice_message.dart';

/// A voice note whose bytes never arrived renders as an honest
/// placeholder — the player is only created once a file resolves, so
/// there is no dead play button to tap.
void main() {
  Future<void> pumpNote(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: VoiceMessage(
            fileName: 'voice_no_such_file_ever.m4a',
            timestamp: DateTime(2025),
            isReceived: true,
            status: '',
            durationMs: 4000,
            directoryProvider: () async => Directory.systemTemp,
          ),
        ),
      ),
    );
    // Bounded pumps for the file lookup; no settle loop, the file
    // simply is not there.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a missing voice note says so', (tester) async {
    await pumpNote(tester);
    expect(find.text('Voice note unavailable'), findsOneWidget);
  });
}
