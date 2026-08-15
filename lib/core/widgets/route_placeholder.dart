import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/onebit_scaffold.dart';
import 'package:onebit/shared/design_system/components/onebit_empty_state.dart';
import 'package:onebit/shared/design_system/components/onebit_technical_card.dart';
import 'package:onebit/shared/design_system/spacing/onebit_spacing.dart';

/// A labeled route shell for screens that later phases will implement.
///
/// Only the shell chrome (app bar + empty state + resolved deep-link
/// parameters) is rendered — no business content, no fake data. Screens
/// replace this widget when their phase lands.
class RoutePlaceholder extends StatelessWidget {
  const RoutePlaceholder({
    required this.title,
    required this.icon,
    this.message,
    this.parameters = const [],
    super.key,
  });

  /// App bar title.
  final String title;

  /// Hero glyph of the empty state.
  final IconData icon;

  /// Empty-state message; defaults to the localized "coming soon" text.
  final String? message;

  /// Resolved deep-link parameters shown in a technical card (label, value).
  final List<(String, String)> parameters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OneBitScaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(OneBitSpacing.m),
        children: [
          const SizedBox(height: OneBitSpacing.xxl),
          OneBitEmptyState(
            icon: icon,
            title: title,
            message: message ?? l10n.routeComingSoon,
          ),
          if (parameters.isNotEmpty) ...[
            const SizedBox(height: OneBitSpacing.xl),
            OneBitTechnicalCard(
              title: l10n.routeDeepLinkParameters,
              content: parameters
                  .map((entry) => '${entry.$1}: ${entry.$2}')
                  .join('\n'),
            ),
          ],
        ],
      ),
    );
  }
}
