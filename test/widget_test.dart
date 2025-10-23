

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_maps/pages/map_page.dart';

void main() {
  testWidgets('MyFavoriteMap renders title', (WidgetTester tester) async {
    // Build the map page without Supabase configured
    await tester.pumpWidget(const MaterialApp(home: MapPage(supabaseConfigured: false)));

    // Verify that the AppBar title is present
    expect(find.text('MyFavoriteMap'), findsOneWidget);
  });
}
