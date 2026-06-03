// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:subnet/main.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('subnet_test_');
    Hive.init(dir.path);
    await Hive.openBox('identity');
    await Hive.openBox('reports');
    await Hive.openBox('settings');
  });

  testWidgets('Subnet starts', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('subnet'), findsOneWidget);
  });
}
