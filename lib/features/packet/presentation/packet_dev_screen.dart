import 'package:flutter/material.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/features/packet/presentation/packet_fragment_tab.dart';
import 'package:onebit/features/packet/presentation/packet_inspector_tab.dart';
import 'package:onebit/features/packet/presentation/packet_logs_tab.dart';
import 'package:onebit/features/packet/presentation/packet_statistics_tab.dart';
import 'package:onebit/features/packet/presentation/packet_wire_tab.dart';

/// Developer dashboard for the packet protocol.
///
/// Not a product screen: it exercises the whole packet pipeline — compose,
/// serialize, decode, fragment, reassemble — and renders the protocol
/// statistics the future messaging layer will consume.
class PacketDevScreen extends StatelessWidget {
  const PacketDevScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: OneBitScaffold(
        appBar: AppBar(
          title: const Text('Packet protocol'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Inspector'),
              Tab(text: 'Wire'),
              Tab(text: 'Fragments'),
              Tab(text: 'Statistics'),
              Tab(text: 'Logs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            PacketInspectorTab(),
            PacketWireTab(),
            PacketFragmentTab(),
            PacketStatisticsTab(),
            PacketLogsTab(),
          ],
        ),
      ),
    );
  }
}
