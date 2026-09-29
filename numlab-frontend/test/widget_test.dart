import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/app.dart';
import 'package:numlab_frontend/injection_container.dart';

void main() {
  setUp(() async {
    await sl.reset();
    await initDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('NumLabApp boots and renders HomeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NumLabApp());
    await tester.pumpAndSettle();

    expect(find.text('NumLab AI'), findsOneWidget);
    expect(find.text('Numerical Solver Workspaces'), findsOneWidget);
    expect(find.text('Categories (6)'), findsOneWidget);
  });
}
