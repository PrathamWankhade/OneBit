import 'package:flutter/material.dart';
import 'package:onebit/core/extensions/build_context_extensions.dart';
import 'package:onebit/core/widgets/route_placeholder.dart';
import 'package:onebit/shared/design_system/icons/onebit_icons.dart';

/// Identity overview screen (future: full profile, keys, trust status).
///
/// Currently renders a [RoutePlaceholder] explaining the feature is not
/// yet available.
class IdentityOverviewScreen extends StatelessWidget {
  const IdentityOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoutePlaceholder(
      title: l10n.identityOverviewTitle,
      icon: OneBitIcons.fingerprint,
      message: l10n.identityOverviewEmpty,
    );
  }
}
