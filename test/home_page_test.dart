import 'dart:async';
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

  testWidgets('renders a typed unavailable state', (tester) async {
    final client = Client(
      const ClientConfig(baseUrl: 'https://worker.example'),
    );

    await tester.pumpWidget(
      GhaIndieWorkerApp(
        client: client,
        request: (_) => Stream.error(
          const ClientException(ClientErrorCode.http),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Worker unavailable'), findsOneWidget);
    expect(find.textContaining('http'), findsOneWidget);
  });

  testWidgets('refresh recovers from unavailable to available', (tester) async {
    final responses = <StreamController<Uint8List>>[];
    final client = Client(
      const ClientConfig(baseUrl: 'https://worker.example'),
    );

    await tester.pumpWidget(
      GhaIndieWorkerApp(
        client: client,
        request: (_) {
          final response = StreamController<Uint8List>();
          responses.add(response);
          return response.stream;
        },
      ),
    );
    await tester.pump();
    expect(responses, hasLength(1));
    responses.first.addError(
      const ClientException(ClientErrorCode.http),
    );
    unawaited(responses.first.close());
    await tester.pumpAndSettle();
    expect(find.text('Worker unavailable'), findsOneWidget);

    await tester.tap(find.byKey(const Key('refresh-health')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(responses, hasLength(2));
    expect(responses.last.hasListener, isTrue);
    responses.last.add(
      Uint8List.fromList(
        utf8.encode('{"ok":true,"service":"recovered-api"}'),
      ),
    );
    unawaited(responses.last.close());
    await tester.pumpAndSettle();

    expect(find.text('Worker available'), findsOneWidget);
    expect(find.textContaining('recovered-api'), findsOneWidget);
  });

  testWidgets('disposing the page cancels an active request stream',
      (tester) async {
    var cancellations = 0;
    final pending = StreamController<Uint8List>(
      onCancel: () {
        cancellations += 1;
      },
    );
    final client = Client(
      const ClientConfig(baseUrl: 'https://worker.example'),
    );

    await tester.pumpWidget(
      GhaIndieWorkerApp(client: client, request: (_) => pending.stream),
    );
    await tester.pump();
    expect(cancellations, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cancellations, 1);
    unawaited(pending.close());
  });
}
