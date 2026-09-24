import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebit/core/theme/app_theme.dart';
import 'package:onebit/features/identity/identity_providers.dart';

/// Lightweight blinking cursor that manages its own timer.
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _show = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _show = !_show);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _show ? '█' : ' ',
      style: AppTheme.technical.copyWith(
        color: AppTheme.brightCyan,
        fontSize: 13,
      ),
    );
  }
}

/// F11 — Onboarding & First-Run Experience.
///
/// 5 screens: Welcome → How It Works → Create Identity → Generating → Ready.
/// Creates the cryptographic identity during the flow and signals completion.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  String? _generatedName;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutExpo,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutExpo,
    );
  }

  void _skipToCreate() {
    _pageController.jumpToPage(2);
  }

  Future<void> _createIdentity() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _generatedName = name);

    // Move to generating page
    _nextPage();

    try {
      final service = ref.read(identityServiceProvider);
      await service.createIdentity(name);

      // Wait for generating animation
      await Future<void>.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Move to ready page
        _nextPage();
      }
    } catch (e) {
      if (mounted) {
        // Go back to create page on error
        _pageController.jumpToPage(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create identity: $e')),
        );
      }
    }
  }

  void _finish() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _WelcomePage(onGetStarted: _nextPage),
            _HowItWorksPage(
              onContinue: _nextPage,
              onBack: _previousPage,
              onSkip: _skipToCreate,
            ),
            _CreateIdentityPage(
              nameController: _nameController,
              onCreate: _createIdentity,
              onBack: _previousPage,
              onSkip: _skipToCreate,
            ),
            const _GeneratingPage(),
            _ReadyPage(name: _generatedName ?? '', onDone: _finish),
          ],
        ),
      ),
    );
  }
}

// ── F11.1: Welcome Screen ────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  const _WelcomePage({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _bootController;
  final List<String> _bootLines = [];

  @override
  void initState() {
    super.initState();
    _bootController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _startBootSequence();
  }

  void _startBootSequence() async {
    const lines = [
      '> initializing onebit v1.0.0...',
      '> loading cryptographic modules...',
      '> scanning bluetooth interface...',
      '> mesh network: ready',
      '> encryption: AES-256-GCM',
      '> identity: null',
      '',
      '> ready.',
    ];

    for (int i = 0; i < lines.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() => _bootLines.add(lines[i]));
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _bootController.forward();
    }
  }

  @override
  void dispose() {
    _bootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),

            // Logo
            Center(
              child: SvgPicture.asset(
                'assets/icons/OneBitLogo.svg',
                width: 160,
                height: 160,
              ),
            ),
            const SizedBox(height: 40),

            // Boot sequence
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                border: Border.all(color: AppTheme.borderSubtle),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _bootLines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _bootLines[i],
                        style: AppTheme.technical.copyWith(
                          color: _bootLines[i].contains('ready')
                              ? AppTheme.brightGreen
                              : _bootLines[i].contains('null')
                                  ? AppTheme.brightYellow
                                  : AppTheme.brightCyan,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  // Blinking cursor
                  const _BlinkingCursor(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // CTA
            AnimatedBuilder(
              animation: _bootController,
              builder: (context, child) {
                return Opacity(
                  opacity: _bootController.value,
                  child: child,
                );
              },
              child: Column(
                children: [
                  Text(
                    'Welcome to OneBit',
                    style: AppTheme.headlineMedium.copyWith(
                      color: AppTheme.brightWhite,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Private, decentralized mesh communication.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onGetStarted,
                      child: const Text('\$ run'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── F11.2: How It Works Screen ──────────────────────────────────

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage({
    required this.onContinue,
    required this.onBack,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with back and skip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                onPressed: onBack,
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'How OneBit works',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Step cards
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _StepCard(
                  icon: Icon(Icons.vpn_key, size: 32, color: AppTheme.accent),
                  stepNumber: 'Step 1',
                  title: 'Create your identity',
                  description:
                      'Your device generates a unique cryptographic key.',
                ),
                SizedBox(height: 12),
                _StepCard(
                  icon: Icon(Icons.wifi_tethering, size: 32, color: AppTheme.accent),
                  stepNumber: 'Step 2',
                  title: 'Discover nearby peers',
                  description: 'Find other OneBit users directly via Bluetooth.',
                ),
                SizedBox(height: 12),
                _StepCard(
                  icon: Icon(Icons.lock_outline, size: 32, color: AppTheme.accent),
                  stepNumber: 'Step 3',
                  title: 'Communicate privately',
                  description:
                      'End-to-end encrypted. No servers. No accounts.',
                ),
              ],
            ),
          ),
        ),

        // Continue button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bgBase,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final Widget icon;
  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 32, height: 32, child: icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepNumber,
                  style: AppTheme.technicalSmall.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── F11.3: Create Identity Screen ───────────────────────────────

class _CreateIdentityPage extends StatefulWidget {
  const _CreateIdentityPage({
    required this.nameController,
    required this.onCreate,
    required this.onBack,
    required this.onSkip,
  });

  final TextEditingController nameController;
  final VoidCallback onCreate;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  State<_CreateIdentityPage> createState() => _CreateIdentityPageState();
}

class _CreateIdentityPageState extends State<_CreateIdentityPage> {
  bool _hasName = false;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() {
    final hasName = widget.nameController.text.trim().isNotEmpty;
    if (hasName != _hasName) {
      setState(() => _hasName = hasName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with back and skip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                onPressed: widget.onBack,
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  'Skip',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Create your identity',
              style: AppTheme.headlineMedium.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Avatar placeholder with camera overlay
                Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.bgOverlay,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _hasName
                            ? widget.nameController.text
                                .trim()[0]
                                .toUpperCase()
                            : '?',
                        style: AppTheme.displayLarge.copyWith(
                          color: _hasName
                              ? AppTheme.accent
                              : AppTheme.textTertiary,
                          fontSize: 40,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: AppTheme.bgBase,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to add profile photo',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 32),

                // Name input
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Display name',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.nameController,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  maxLength: 32,
                  decoration: InputDecoration(
                    hintText: 'Enter your name...',
                    hintStyle: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textDisabled,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.accent,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) {
                    if (_hasName) widget.onCreate();
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your identity is created on your device. No account required.',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),

                const Spacer(),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _hasName ? widget.onCreate : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.bgBase,
                      disabledBackgroundColor: AppTheme.bgMuted,
                      disabledForegroundColor: AppTheme.textDisabled,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Create identity'),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── F11.4: Generating Screen ────────────────────────────────────

class _GeneratingPage extends StatefulWidget {
  const _GeneratingPage();

  @override
  State<_GeneratingPage> createState() => _GeneratingPageState();
}

class _GeneratingPageState extends State<_GeneratingPage> {
  final List<String> _logLines = [];

  @override
  void initState() {
    super.initState();
    _startGeneration();
  }

  void _startGeneration() async {
    const steps = [
      '> generating ed25519 keypair...',
      '> deriving fingerprint...',
      '> creating identity certificate...',
      '> signing with private key...',
      '> storing in secure enclave...',
      '',
      '> identity generated successfully.',
    ];

    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() => _logLines.add(steps[i]));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Terminal window
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              border: Border.all(color: AppTheme.borderSubtle),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'onebit@mesh:~\$',
                  style: AppTheme.technical.copyWith(
                    color: AppTheme.brightGreen,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < _logLines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _logLines[i],
                      style: AppTheme.technical.copyWith(
                        color: _logLines[i].contains('successfully')
                            ? AppTheme.brightGreen
                            : _logLines[i].contains('>')
                                ? AppTheme.brightCyan
                                : AppTheme.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const _BlinkingCursor(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── F11.5: Identity Ready Screen ────────────────────────────────

class _ReadyPage extends ConsumerWidget {
  const _ReadyPage({
    required this.name,
    required this.onDone,
  });

  final String name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(localIdentityProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Checkmark
          const Icon(
            Icons.check_circle,
            size: 64,
            color: AppTheme.green,
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Identity created',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.bgElevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTheme.displayLarge.copyWith(
                color: AppTheme.accent,
                fontSize: 36,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            name,
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // OneBit ID
          identityAsync.when(
            loading: () => const SizedBox(height: 60),
            error: (_, _) => const SizedBox(height: 60),
            data: (identity) {
              if (identity?.identityId == null) {
                return const SizedBox(height: 60);
              }
              final id = identity!.identityId!;
              final formatted = _formatIdentityId(id);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'OneBit ID',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatted,
                      style: AppTheme.technical.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Your identity is stored securely\non this device only.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textTertiary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),

          // Start button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bgBase,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Start using OneBit'),
            ),
          ),
          const SizedBox(height: 12),

          // Save backup button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                // TODO: Implement backup
              },
              child: Text(
                'Save backup',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatIdentityId(String id) {
    if (id.length <= 16) return id;
    final buffer = StringBuffer();
    for (var i = 0; i < id.length && i < 16; i += 4) {
      if (buffer.isNotEmpty) buffer.write(':');
      buffer.write(id.substring(i, i + 4));
    }
    return buffer.toString();
  }
}
