import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Dynamic input component for 1D numeric vectors (`List<num>`).
class DynamicVectorField extends StatefulWidget {
  const DynamicVectorField({
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
  State<DynamicVectorField> createState() => _DynamicVectorFieldState();
}

class _DynamicVectorFieldState extends State<DynamicVectorField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatVector(widget.value));
  }

  @override
  void didUpdateWidget(covariant DynamicVectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final formatted = _formatVector(widget.value);
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

  String _formatVector(dynamic val) {
    if (val is List) {
      return val.join(', ');
    }
    return val?.toString() ?? '';
  }

  void _handleChanged(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }

    var clean = trimmed;
    if (clean.startsWith('[') && clean.endsWith(']')) {
      clean = clean.substring(1, clean.length - 1).trim();
    }
    if (clean.isEmpty) {
      widget.onChanged(const <num>[]);
      return;
    }

    final parts = clean.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty);
    final parsedList = <num>[];
    var isValid = true;
    for (final part in parts) {
      final n = num.tryParse(part);
      if (n != null) {
        parsedList.add(n);
      } else {
        isValid = false;
        break;
      }
    }

    if (isValid) {
      widget.onChanged(parsedList);
    } else {
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
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: widget.config.placeholder ?? 'e.g. 1.0, 2.0, 3.0',
          helperText:
              widget.config.helperText ??
              'Enter numbers separated by commas or spaces',
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
        ),
        onChanged: _handleChanged,
      ),
    );
  }
}
