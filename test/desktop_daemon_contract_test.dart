import 'package:flutter_test/flutter_test.dart';
import 'package:gha_indie_worker_flutter/src/desktop/daemon_client.dart';
import 'package:gha_indie_worker_flutter/src/desktop/daemon_models.dart';

void main() {
  test('canonical daemon status payload parses fail-closed fields', () {
    final status = DesktopDaemonStatus.fromJson(<String, dynamic>{
      'product': 'indiebuild',
      'execution_backend': 'scintilla-run',
      'isolation': 'ephemeral-per-job',
      'worker_reuse': 'forbidden',
      'in_flight_dispatches': 2,
      'max_in_flight_dispatches': 32,
      'uptime_ms': 1234,
      'scintilla': <String, dynamic>{'status': 'ok'},
    });

    expect(status.product, 'indiebuild');
    expect(status.executionBackend, 'scintilla-run');
    expect(status.isolation, 'ephemeral-per-job');
    expect(status.workerReuse, 'forbidden');
    expect(status.inFlightDispatches, 2);
    expect(status.maxInFlightDispatches, 32);
    expect(status.uptimeMs, 1234);
    expect(status.scintilla['status'], 'ok');
  });

  test(
    'desktop client accepts literal loopback and rejects hostname aliases',
    () {
      expect(
        () => DesktopDaemonClient(
          baseUrl: 'http://127.0.0.1:8770',
          tokenFile: '/tmp/unused-token',
        ),
        returnsNormally,
      );
      expect(
        () => DesktopDaemonClient(
          baseUrl: 'http://[::1]:8770',
          tokenFile: '/tmp/unused-token',
        ),
        returnsNormally,
      );
      expect(
        () => DesktopDaemonClient(
          baseUrl: 'http://localhost:8770',
          tokenFile: '/tmp/unused-token',
        ),
        throwsArgumentError,
      );
      expect(
        () => DesktopDaemonClient(
          baseUrl: 'https://127.0.0.1:8770',
          tokenFile: '/tmp/unused-token',
        ),
        throwsArgumentError,
      );
    },
  );
}
