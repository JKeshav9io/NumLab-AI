import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

void main() {
  group('SolverFieldValidation', () {
    test(
      'required field validation works for null, empty strings, and empty lists',
      () {
        const validation = SolverFieldValidation();

        expect(
          validation.validate(null, fieldLabel: 'Equation'),
          'Equation is required',
        );
        expect(
          validation.validate('', fieldLabel: 'Equation'),
          'Equation is required',
        );
        expect(
          validation.validate('   ', fieldLabel: 'Equation'),
          'Equation is required',
        );
        expect(
          validation.validate(<dynamic>[], fieldLabel: 'Points'),
          'Points is required',
        );
        expect(validation.validate('x^2 - 4', fieldLabel: 'Equation'), isNull);
        expect(validation.validate([1, 2], fieldLabel: 'Points'), isNull);
      },
    );

    test('optional field validation returns null for null or empty values', () {
      const validation = SolverFieldValidation(isRequired: false);

      expect(validation.validate(null, fieldLabel: 'OptionalField'), isNull);
      expect(validation.validate('', fieldLabel: 'OptionalField'), isNull);
    });

    test(
      'numeric validation: isPositive, minValue, maxValue, even, divisibleBy',
      () {
        const positiveVal = SolverFieldValidation(
          isPositive: true,
          maxValue: 1.0,
        );
        expect(
          positiveVal.validate(0, fieldLabel: 'Tolerance'),
          'Tolerance must be positive',
        );
        expect(
          positiveVal.validate(-0.01, fieldLabel: 'Tolerance'),
          'Tolerance must be positive',
        );
        expect(
          positiveVal.validate(1.5, fieldLabel: 'Tolerance'),
          'Tolerance must not exceed 1.0',
        );
        expect(positiveVal.validate(0.0001, fieldLabel: 'Tolerance'), isNull);

        const intRangeVal = SolverFieldValidation(minValue: 1, maxValue: 1000);
        expect(
          intRangeVal.validate(0, fieldLabel: 'Iterations'),
          'Iterations must be at least 1',
        );
        expect(
          intRangeVal.validate(1001, fieldLabel: 'Iterations'),
          'Iterations must not exceed 1000',
        );
        expect(intRangeVal.validate(100, fieldLabel: 'Iterations'), isNull);

        const evenVal = SolverFieldValidation(mustBeEven: true);
        expect(
          evenVal.validate(3, fieldLabel: 'Subintervals'),
          'Subintervals must be an even number',
        );
        expect(evenVal.validate(4, fieldLabel: 'Subintervals'), isNull);

        const div3Val = SolverFieldValidation(mustBeDivisibleBy: 3);
        expect(
          div3Val.validate(4, fieldLabel: 'Subintervals'),
          'Subintervals must be divisible by 3',
        );
        expect(div3Val.validate(6, fieldLabel: 'Subintervals'), isNull);
      },
    );

    test('list items validation: minItems, maxItems', () {
      const listVal = SolverFieldValidation(minItems: 2, maxItems: 5);
      expect(
        listVal.validate([1], fieldLabel: 'Points'),
        'Points requires at least 2 items',
      );
      expect(
        listVal.validate([1, 2, 3, 4, 5, 6], fieldLabel: 'Points'),
        'Points must not exceed 5 items',
      );
      expect(listVal.validate([1, 2, 3], fieldLabel: 'Points'), isNull);
    });

    test('allowedValues validation', () {
      const enumVal = SolverFieldValidation(
        allowedValues: ['forward', 'backward', 'central'],
      );
      expect(
        enumVal.validate('invalid', fieldLabel: 'Variant'),
        'Variant must be one of: forward, backward, central',
      );
      expect(enumVal.validate('central', fieldLabel: 'Variant'), isNull);
    });
  });

  group('SolverInputFieldConfig', () {
    test('validate delegates to validation with label', () {
      const field = SolverInputFieldConfig(
        name: 'equation',
        label: 'Equation f(x)',
        type: SolverInputFieldType.equation,
        validation: SolverFieldValidation(maxLength: 10),
      );

      expect(field.validate(''), 'Equation f(x) is required');
      expect(
        field.validate('12345678901'),
        'Equation f(x) must not exceed 10 characters',
      );
      expect(field.validate('x^2 - 1'), isNull);
    });
  });

  group('SolverMethodConfig', () {
    test('defaultPayload generates map of default values', () {
      final config = SolverMethodRegistry.bisection;
      final defaults = config.defaultPayload();

      expect(defaults['tolerance'], 0.0001);
      expect(defaults['maxIterations'], 100);
      expect(defaults['includeExplanation'], true);
      expect(defaults['includeGraphData'], true);
      expect(defaults.containsKey('equation'), isFalse);
    });

    test('getField returns matching field config or null', () {
      final config = SolverMethodRegistry.bisection;

      expect(config.getField('equation')?.name, 'equation');
      expect(config.getField('tolerance')?.type, SolverInputFieldType.number);
      expect(config.getField('nonExistent'), isNull);
    });
  });
}
