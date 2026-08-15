import 'package:flutter/foundation.dart';

/// Severity of a validation issue.
enum ValidationSeverity {
  /// Blocks the operation (size, type, checksum violations).
  error,

  /// Accepted with a caveat (unusual extension, missing metadata).
  warning,
}

/// One finding of a validation run.
@immutable
final class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.message,
    this.severity = ValidationSeverity.error,
  });

  /// Stable machine-readable id (e.g. `tooLarge`, `badExtension`).
  final String code;

  final String message;
  final ValidationSeverity severity;

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue &&
      other.code == code &&
      other.message == message &&
      other.severity == severity;

  @override
  int get hashCode => Object.hash(code, message, severity);

  @override
  String toString() => 'ValidationIssue($code [$severity] $message)';
}

/// Outcome of a validation run.
@immutable
final class ValidationResult {
  const ValidationResult({this.issues = const []});

  final List<ValidationIssue> issues;

  bool get isOk => issues.every((i) => i.severity != ValidationSeverity.error);

  bool get hasErrors => !isOk;

  List<ValidationIssue> get errors => issues
      .where((i) => i.severity == ValidationSeverity.error)
      .toList(growable: false);

  static const ValidationResult ok = ValidationResult();

  ValidationResult plus(ValidationIssue issue) =>
      ValidationResult(issues: [...issues, issue]);

  ValidationResult plusAll(Iterable<ValidationIssue> more) =>
      ValidationResult(issues: [...issues, ...more]);

  @override
  bool operator ==(Object other) =>
      other is ValidationResult &&
      other.issues.length == issues.length &&
      _issuesEqual(other);

  @override
  int get hashCode => Object.hashAll(issues);

  bool _issuesEqual(ValidationResult other) {
    for (var i = 0; i < issues.length; i++) {
      if (issues[i] != other.issues[i]) return false;
    }
    return true;
  }
}
