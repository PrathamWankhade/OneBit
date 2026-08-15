import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/navigation/app_route_paths.dart';
import 'package:onebit/core/widgets/route_placeholder.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

/// New-message composer shell for a channel.
class ComposeMessageScreen extends StatelessWidget {
  const ComposeMessageScreen({required this.channelId, super.key});

  /// Channel identifier from the route (see [AppRoutePaths.composeMessage]).
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoutePlaceholder(
      title: l10n.composeMessageTitle,
      icon: OneBitIcons.send,
      parameters: [(l10n.channelIdLabel, channelId)],
    );
  }
}
