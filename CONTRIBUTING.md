# Contributing to OneBit

Thank you for your interest in contributing to OneBit. This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- Flutter SDK 3.13+
- Dart SDK 3.13+
- Android Studio or VS Code with Flutter/Dart plugins
- A physical Android or iOS device (BLE does not work on emulators)

### Setup

```bash
# Fork and clone the repository
git clone https://github.com/your-username/onebit.git
cd onebit

# Install dependencies
flutter pub get

# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Verify everything works
flutter analyze
flutter test
```

## Development Workflow

### Branch Naming

Use descriptive branch names with prefixes:

| Prefix | Purpose |
|--------|---------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `refactor/` | Code refactoring |
| `docs/` | Documentation changes |
| `test/` | Adding or updating tests |

Example: `feature/voice-message-waveform`

### Commit Messages

Write clear, concise commit messages:

```
Add waveform visualization to voice messages

- Add VoiceRecordingWidget with animated waveform
- Integrate with message composer
- Add RepaintBoundary for performance
```

### Code Style

- Follow the existing code style and conventions
- Use `AppTheme` tokens for all colors, spacing, and typography
- Use the shared component library in `lib/features/ui/components/`
- Prefer `const` constructors where possible
- Keep files under 500 lines; split into multiple files if needed

### Design System

Always use `AppTheme` tokens instead of hardcoded values:

```dart
// Good
Container(
  color: AppTheme.bgElevated,
  padding: const EdgeInsets.all(AppTheme.space16),
  child: Text('Hello', style: AppTheme.bodyMedium),
)

// Bad
Container(
  color: Color(0xFF141414),
  padding: const EdgeInsets.all(16),
  child: Text('Hello', style: TextStyle(fontSize: 14)),
)
```

### Testing

- Write tests for new features and bug fixes
- Run `flutter test` before submitting
- Aim for meaningful tests, not just coverage numbers
- Use mockito for mocking dependencies

```bash
# Run all tests
flutter test

# Run tests for a specific feature
flutter test test/features/nearby/

# Generate mock code after changing mock annotations
dart run build_runner build --delete-conflicting-outputs
```

### Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commits
3. Run `flutter analyze` and `flutter test`
4. Push your branch and create a pull request
5. Fill out the PR template with:
   - What changed
   - Why it changed
   - How to test it
   - Screenshots (if UI changed)

### Code Review

All PRs require review before merging. Reviewers will check:

- Code quality and style consistency
- Test coverage for new code
- Performance implications
- Security considerations
- Documentation updates (if needed)

## Architecture

OneBit follows a feature-based architecture:

```
lib/features/
\u251c\u2500\u2500 feature_name/
\u2502   \u251c\u2500\u2500 data/           Data sources, repositories
\u2502   \u251c\u2500\u2500 domain/        Business logic (if complex)
\u2502   \u251c\u2500\u2500 presentation/  UI screens, widgets
\u2502   \u2514\u2500\u2500 providers/     Riverpod providers
\u2514\u2500\u2500 shared/          Shared widgets, utilities
```

### Key Patterns

- **Riverpod** for state management (all providers are app-scoped keepAlive)
- **GoRouter** for navigation with slide transitions
- **Drift** for type-safe SQLite database access
- **Repository pattern** for data access abstraction

## Reporting Issues

### Bug Reports

When reporting bugs, include:

- Device model and OS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or screen recordings (if applicable)
- Log output (if available)

### Feature Requests

For feature requests, describe:

- The problem you're trying to solve
- Your proposed solution
- Alternatives you considered
- Any mockups or examples

## Security

If you discover a security vulnerability:

1. **Do not** open a public GitHub issue
2. Contact the maintainer directly
3. Allow time for a fix before public disclosure

## License

By contributing to OneBit, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing, feel free to open a discussion or reach out to the maintainer.
