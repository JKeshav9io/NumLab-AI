import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Dynamic multi-line input component for 2D coordinate lists (`List<Map<String, num>>`).
class DynamicPointListField extends StatefulWidget {
  const DynamicPointListField({
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
  State<DynamicPointListField> createState() => _DynamicPointListFieldState();
}

class _DynamicPointListFieldState extends State<DynamicPointListField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatPoints(widget.value));
  }

  @override
  void didUpdateWidget(covariant DynamicPointListField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final formatted = _formatPoints(widget.value);
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

  String _formatPoints(dynamic val) {
    if (val is List) {
      return val
          .map((pt) {
            if (pt is Map) {
              final x = pt['x'];
              final y = pt['y'];
              return '$x, $y';
            }
            return pt.toString();
          })
          .join('\n');
    }
    return val?.toString() ?? '';
  }

  void _handleChanged(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }

    final lines = trimmed
        .split(RegExp(r'[\n;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    final points = <Map<String, num>>[];
    var isValid = true;

    for (final line in lines) {
      final clean = line.replaceAll('(', '').replaceAll(')', '').trim();
      final parts = clean
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        final x = num.tryParse(parts[0]);
        final y = num.tryParse(parts[1]);
        if (x != null && y != null) {
          points.add({'x': x, 'y': y});
        } else {
          isValid = false;
          break;
        }
      } else {
        isValid = false;
        break;
      }
    }

    if (isValid && points.isNotEmpty) {
      widget.onChanged(points);
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
        minLines: 3,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        style: AppTypography.codeMono.copyWith(fontSize: 14),
        decoration: InputDecoration(
          labelText: labelText,
          hintText:
              widget.config.placeholder ?? 'e.g.\n1.0, 2.0\n2.0, 3.0\n3.0, 5.0',
          helperText:
              widget.config.helperText ??
              'Enter (x, y) coordinates per line (e.g. 1.0, 2.0)',
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        onChanged: _handleChanged,
      ),
    );
  }
}
