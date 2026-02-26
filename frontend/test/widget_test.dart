import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_permit_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkPermitApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
