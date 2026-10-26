import 'package:flutter_test/flutter_test.dart';
import 'package:scout_fpl_app/main.dart';

void main() {
  testWidgets('App renders title test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScoutFplApp());
    expect(find.text('FPL Best Buys'), findsOneWidget);
  });
}
