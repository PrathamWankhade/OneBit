import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/route_placeholder.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

/// Unified QR hub screen (future: identity QR + scanner in one place).
///
/// Currently renders a [RoutePlaceholder] explaining the feature is not
/// yet available.
class QrHubScreen extends StatelessWidget {
  const QrHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoutePlaceholder(
      title: l10n.qrHubTitle,
      icon: OneBitIcons.qrIdentity,
      message: l10n.qrHubEmpty,
    );
  }
}
