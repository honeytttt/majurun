import 'package:flutter_test/flutter_test.dart';
import 'package:majurun/main.dart';

void main() {
  testWidgets('Counter smoke test', (WidgetTester tester) async {
    // Change MajurunApp to MyApp to match main.dart
    await tester.pumpWidget(const MyApp()); 
    expect(find.text('App Loaded'), findsOneWidget);
  });
}