import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

/// Dynamic multi-line input component for 2D numeric matrices (`List<List<num>>`).
class DynamicMatrixField extends StatefulWidget {
  const DynamicMatrixField({
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
  State<DynamicMatrixField> createState() => _DynamicMatrixFieldState();
}

class _DynamicMatrixFieldState extends State<DynamicMatrixField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatMatrix(widget.value));
  }

  @override
  void didUpdateWidget(covariant DynamicMatrixField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final formatted = _formatMatrix(widget.value);
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

  String _formatMatrix(dynamic val) {
    if (val is List) {
      return val
          .map((row) => row is List ? row.join(', ') : row.toString())
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

    var clean = trimmed;
    // Handle outer brackets e.g. [[1, 2], [3, 4]]
    if (clean.startsWith('[[') && clean.endsWith(']]')) {
      clean = clean.substring(1, clean.length - 1);
    }

    final rowLines = clean
        .split(RegExp(r'[\n;]+'))
        .map((s) => s.replaceAll('[', '').replaceAll(']', '').trim())
        .where((s) => s.isNotEmpty);

    final matrix = <List<num>>[];
    var isValid = true;

    for (final line in rowLines) {
      final row = <num>[];
      final cells = line.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty);
      for (final cell in cells) {
        final n = num.tryParse(cell);
        if (n != null) {
          row.add(n);
        } else {
          isValid = false;
          break;
        }
      }
      if (!isValid) break;
      if (row.isNotEmpty) {
        matrix.add(row);
      }
    }

    if (isValid && matrix.isNotEmpty) {
      widget.onChanged(matrix);
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
          hintText: widget.config.placeholder ?? 'e.g.\n2.0, 1.0\n1.0, 3.0',
          helperText:
              widget.config.helperText ??
              'Enter rows on new lines or separated by semicolons (e.g. 2 1; 1 3)',
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        onChanged: _handleChanged,
      ),
    );
  }
}
