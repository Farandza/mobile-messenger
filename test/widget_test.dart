import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile_messenger/main.dart';

void main() {
  testWidgets('shows application loading state', (tester) async {
    await tester.pumpWidget(const Nimble());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
