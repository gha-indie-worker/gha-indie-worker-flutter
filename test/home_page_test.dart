import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gha_indie_worker_client/gha_indie_worker_client.dart';
import 'package:gha_indie_worker_flutter/src/app.dart';

void main() {
  testWidgets('renders the available state and refreshes through the stream',
      (tester) async {
    var requestCount = 0;
    final client = Client(
      const ClientConfig(baseUrl: 'https://worker.example'),
    );

    await tester.pumpWidget(
      GhaIndieWorkerApp(
        client: client,
        request: (_) {
          requestCount += 1;
          return Stream.value(
            Uint8List.fromList(
              utf8.encode('{"ok":true,"service":"test-api"}'),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Worker available'), findsOneWidget);
    expect(find.textContaining('test-api'), findsOneWidget);
    expect(requestCount, 1);

    await tester.tap(find.byKey(const Key('refresh-health')));
    await tester.pumpAndSettle();
    expect(requestCount, 2);
  });
}
