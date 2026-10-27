import 'daemon_models.dart';

class DesktopDaemonClient {
  DesktopDaemonClient({String? baseUrl, String? tokenFile});

  bool get supported => false;

  Future<DesktopDaemonStatus> status() {
    return Future<DesktopDaemonStatus>.error(
      UnsupportedError(
        'GIW desktop daemon status is available only on desktop dart:io targets',
      ),
    );
  }

  void close() {}
}
