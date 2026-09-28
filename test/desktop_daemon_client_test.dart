import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gha_indie_worker_flutter/src/desktop/daemon_client.dart';

void main() {
  group('DesktopDaemonClient endpoint validation', () {
    test('accepts numeric loopback URLs with explicit ports', () {
      final ipv4 = DesktopDaemonClient(
        baseUrl: 'http://127.0.0.1:18440',
        tokenFile: 'unused',
      );
      final ipv6 = DesktopDaemonClient(
        baseUrl: 'http://[::1]:18440/',
        tokenFile: 'unused',
      );

      ipv4.close();
      ipv6.close();
    });

    const invalidUrls = <String>[
      'http://localhost:18440',
      'http://127.0.0.1',
      'https://127.0.0.1:18440',
      'http://user:pass@127.0.0.1:18440',
      'http://127.0.0.1:18440/v1',
      'http://127.0.0.1:18440?mode=unsafe',
      'http://127.0.0.1:18440#fragment',
      'http://127.0.0.1:0',
      'http://127.0.0.1:65536',
    ];

    for (final raw in invalidUrls) {
      test('rejects $raw', () {
        expect(
          () => DesktopDaemonClient(baseUrl: raw, tokenFile: 'unused'),
          throwsArgumentError,
        );
      });
    }
  });

  test('rejects URI-shaping process names before daemon I/O', () async {
    final client = DesktopDaemonClient(
      baseUrl: 'http://127.0.0.1:18440',
      tokenFile: 'unused',
    );
    addTearDown(client.close);

    for (final name in <String>[
      '',
      '.',
      '..',
      '../daemon',
      'svc/name',
      r'svc\name',
      'svc?mode=unsafe',
      'svc#fragment',
      'svc%2Fother',
      'white space',
    ]) {
      await expectLater(client.startProcess(name), throwsArgumentError);
    }
  });

  test('rejects oversized daemon responses', () async {
    final tempDir = await Directory.systemTemp.createTemp('giw-client-test-');
    addTearDown(() => tempDir.delete(recursive: true));

    final tokenFile = File(
      '\${tempDir.path}\${Platform.pathSeparator}token',
    );
    await tokenFile.writeAsString(List<String>.filled(32, 'x').join());

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"padding":"');
      request.response.write(
        List<String>.filled((1024 * 1024) + 128, 'a').join(),
      );
      request.response.write('"}');
      await request.response.close();
    });

    final client = DesktopDaemonClient(
      baseUrl: 'http://127.0.0.1:\${server.port}',
      tokenFile: tokenFile.path,
    );
    addTearDown(client.close);

    await expectLater(
      client.status(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('maximum response size'),
        ),
      ),
    );
  });

  test('fails closed on an unsupported daemon protocol version', () async {
    final tempDir = await Directory.systemTemp.createTemp('giw-client-test-');
    addTearDown(() => tempDir.delete(recursive: true));

    final tokenFile = File(
      '\${tempDir.path}\${Platform.pathSeparator}token',
    );
    await tokenFile.writeAsString(List<String>.filled(32, 'x').join());

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"protocol_version":0,"mode":"test","bind":"127.0.0.1",'
        '"manifest_version":1,"services":[],"tunnel":null,"keep_awake":false}',
      );
      await request.response.close();
    });

    final client = DesktopDaemonClient(
      baseUrl: 'http://127.0.0.1:\${server.port}',
      tokenFile: tokenFile.path,
    );
    addTearDown(client.close);

    await expectLater(
      client.status(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('unsupported'),
        ),
      ),
    );
  });
}
