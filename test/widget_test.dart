import 'package:flutter_test/flutter_test.dart';
import 'package:outfitly/main.dart';

void main() {
  testWidgets('App boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OutfitlyApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });
}
