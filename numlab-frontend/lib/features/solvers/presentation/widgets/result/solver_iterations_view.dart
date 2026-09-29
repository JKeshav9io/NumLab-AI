import 'package:flutter/material.dart';
import 'package:numlab_frontend/core/theme/app_spacing.dart';
import 'package:numlab_frontend/core/theme/app_typography.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_final_answer_view.dart';

/// Reusable view for displaying iteration history steps or intermediate calculations.
class SolverIterationsView extends StatelessWidget {
  const SolverIterationsView({
    required this.iterations,
    super.key,
  });

  final List<dynamic> iterations;

  @override
  Widget build(BuildContext context) {
    if (iterations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('solver_result_iterations_section'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: ExpansionTile(
        key: const Key('solver_iterations_expansion_tile'),
        title: Text(
          'Iteration Steps (${iterations.length})',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: AppSpacing.xs),
        children: [
          Builder(
            builder: (context) {
              final columnKeys = _extractColumnKeys();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 48,
                  columns: _extractColumns(columnKeys),
                  rows: _extractRows(columnKeys),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<String> _extractColumnKeys() {
    final keySet = <String>{};
    for (final item in iterations) {
      if (item is Map) {
        for (final k in item.keys) {
          keySet.add(k.toString());
        }
      }
    }
    return keySet.toList();
  }

  List<DataColumn> _extractColumns(List<String> columnKeys) {
    if (columnKeys.isNotEmpty) {
      return columnKeys.map((k) {
        return DataColumn(
          label: Text(
            SolverFinalAnswerView.formatKeyLabel(k),
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList();
    }

    return const [
      DataColumn(label: Text('Step')),
      DataColumn(label: Text('Value')),
    ];
  }

  List<DataRow> _extractRows(List<String> columnKeys) {
    return iterations.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;

      if (columnKeys.isNotEmpty && row is Map) {
        final cells = columnKeys.map((k) {
          final val = row[k];
          final text = val != null
              ? SolverFinalAnswerView.formatValue(val)
              : '—';

          return DataCell(
            Text(
              text,
              style: AppTypography.codeMono.copyWith(fontSize: 12),
            ),
          );
        }).toList();

        return DataRow(
          key: ValueKey('iteration_row_$index'),
          cells: cells,
        );
      }

      return DataRow(
        key: ValueKey('iteration_row_$index'),
        cells: [
          DataCell(Text('${index + 1}')),
          DataCell(
            Text(
              SolverFinalAnswerView.formatValue(row),
              style: AppTypography.codeMono.copyWith(fontSize: 12),
            ),
          ),
        ],
      );
    }).toList();
  }
}
