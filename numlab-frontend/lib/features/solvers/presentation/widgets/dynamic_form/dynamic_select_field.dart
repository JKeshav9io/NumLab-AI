import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Dynamic dropdown selection field for discrete choice options.
class DynamicSelectField extends StatelessWidget {
  const DynamicSelectField({
    required this.config,
    required this.value,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final SolverInputFieldConfig config;
  final String? value;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = config.options ?? const [];
    final isRequired = config.validation.isRequired;
    final labelText = isRequired ? '${config.label} *' : config.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        key: Key('field_${config.name}'),
        initialValue: options.any((opt) => opt.value == value) ? value : null,
        decoration: InputDecoration(
          labelText: labelText,
          helperText: config.helperText,
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
        items: options.map((opt) {
          return DropdownMenuItem<String>(
            key: Key('option_${config.name}_${opt.value}'),
            value: opt.value,
            child: Text(opt.label),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
