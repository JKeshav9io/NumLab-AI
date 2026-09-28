import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Dynamic text input field for equations, floating-point numbers, and integer parameters.
class DynamicTextField extends StatefulWidget {
  const DynamicTextField({
    required this.config,
    required this.value,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final SolverInputFieldConfig config;
  final dynamic value;
  final String? errorText;
  final ValueChanged<dynamic> onChanged;

  @override
  State<DynamicTextField> createState() => _DynamicTextFieldState();
}

class _DynamicTextFieldState extends State<DynamicTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatInitialValue(widget.value),
    );
  }

  @override
  void didUpdateWidget(covariant DynamicTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final formatted = _formatInitialValue(widget.value);
      if (_controller.text != formatted) {
        _controller.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatInitialValue(dynamic val) {
    if (val == null) return '';
    return val.toString();
  }

  TextInputType _getKeyboardType() {
    switch (widget.config.type) {
      case SolverInputFieldType.equation:
        return TextInputType.text;
      case SolverInputFieldType.number:
        return const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        );
      case SolverInputFieldType.integer:
        return const TextInputType.numberWithOptions(signed: true);
      case SolverInputFieldType.boolean:
      case SolverInputFieldType.select:
      case SolverInputFieldType.matrix:
      case SolverInputFieldType.vector:
      case SolverInputFieldType.pointList:
        return TextInputType.text;
    }
  }

  void _handleChanged(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }

    switch (widget.config.type) {
      case SolverInputFieldType.equation:
        widget.onChanged(rawText);
      case SolverInputFieldType.number:
        final parsed = num.tryParse(trimmed);
        widget.onChanged(parsed ?? trimmed);
      case SolverInputFieldType.integer:
        final parsed = int.tryParse(trimmed);
        widget.onChanged(parsed ?? trimmed);
      case SolverInputFieldType.boolean:
      case SolverInputFieldType.select:
      case SolverInputFieldType.matrix:
      case SolverInputFieldType.vector:
      case SolverInputFieldType.pointList:
        widget.onChanged(rawText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRequired = widget.config.validation.isRequired;
    final labelText = isRequired
        ? '${widget.config.label} *'
        : widget.config.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        key: Key('field_${widget.config.name}'),
        controller: _controller,
        keyboardType: _getKeyboardType(),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: widget.config.placeholder,
          helperText: widget.config.helperText,
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
        ),
        onChanged: _handleChanged,
      ),
    );
  }
}
