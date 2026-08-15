import 'package:flutter/material.dart';

/// Selection controls in the OneBit visual language.
///
/// Every control carries an optional semantic label; colors resolve from the
/// ambient `ColorScheme`. No selection state is owned here.

/// Checkbox with an optional semantic label.
class OneBitCheckbox extends StatelessWidget {
  const OneBitCheckbox({
    required this.value,
    this.onChanged,
    this.label,
    this.tristate = false,
    super.key,
  });

  /// Current tri-state value.
  final bool? value;

  /// Change callback; `null` renders the control disabled.
  final ValueChanged<bool?>? onChanged;

  /// Semantics label.
  final String? label;

  /// Enables the indeterminate state (`null` value).
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        tristate: tristate,
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

/// Switch with an optional semantic label.
class OneBitSwitch extends StatelessWidget {
  const OneBitSwitch({
    required this.value,
    this.onChanged,
    this.label,
    super.key,
  });

  /// Current value.
  final bool value;

  /// Change callback; `null` renders the control disabled.
  final ValueChanged<bool>? onChanged;

  /// Semantics label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

/// Radio entry with an optional semantic label.
///
/// Wraps `RadioGroup` (Material's non-deprecated grouping API); the group
/// value and change callback are owned by the caller.
class OneBitRadio<T> extends StatelessWidget {
  const OneBitRadio({
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.label,
    super.key,
  });

  /// This entry's value.
  final T value;

  /// Currently selected group value.
  final T? groupValue;

  /// Change callback; `null` renders the control disabled.
  final ValueChanged<T?>? onChanged;

  /// Semantics label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged ?? (_) {},
      child: Semantics(
        label: label,
        child: Radio<T>(
          value: value,
          enabled: enabled,
          visualDensity: VisualDensity.standard,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
