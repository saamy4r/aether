import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aether/app.dart';

void main() {
  testWidgets('App renders desktop screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AetherApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
