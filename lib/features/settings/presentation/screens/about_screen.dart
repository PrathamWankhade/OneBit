import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/core/version/app_version.dart';

/// F8 — About OneBit screen.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        backgroundColor: AppTheme.bgBase,
        title: Text(
          'About OneBit',
          style: AppTheme.titleLarge.copyWith(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 48),
          Center(
            child:             SvgPicture.asset(
              'assets/icons/OneBitLogo.svg',
              width: 120,
              height: 120,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'OneBit',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Decentralized mesh messenger',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const _InfoRow(label: 'Version', value: AppVersion.current),
                const Divider(height: 24, color: AppTheme.bgMuted),
                const _InfoRow(label: 'Build', value: AppVersion.build),
                const Divider(height: 24, color: AppTheme.bgMuted),
                GestureDetector(
                  onTap: () => showLicensePage(context: context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Licenses',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.textTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'OneBit is a decentralized, peer-to-peer messenger that '
            'communicates over Bluetooth Low Energy. No servers, no internet, '
            'just direct device-to-device encryption.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }
}
