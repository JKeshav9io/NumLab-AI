import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Dynamic toggle / switch field for boolean solver options.
class DynamicBooleanField extends StatelessWidget {
  const DynamicBooleanField({
    required this.config,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final SolverInputFieldConfig config;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SwitchListTile(
        key: Key('field_${config.name}'),
        contentPadding: EdgeInsets.zero,
        title: Text(config.label),
        subtitle: config.helperText != null
            ? Text(
                config.helperText!,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
