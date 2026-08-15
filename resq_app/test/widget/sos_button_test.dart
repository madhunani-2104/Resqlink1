import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq_app/features/sos/widgets/sos_button.dart';

void main() {
  testWidgets('SosButton renders correctly and responds to tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SosButton(
            isActive: false,
            onTrigger: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('PRESS FOR SOS'), findsOneWidget);
    await tester.tap(find.byType(SosButton));
    expect(tapped, isTrue);
  });
}
