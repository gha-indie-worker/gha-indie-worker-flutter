import 'daemon_models.dart';

class DesktopDaemonClient {
  DesktopDaemonClient({String? baseUrl, String? tokenFile});

  bool get supported => false;

  Future<DesktopDaemonStatus> status() {
    return Future<DesktopDaemonStatus>.error(
      UnsupportedError('GIW desktop daemon control is available only on desktop dart:io targets'),
    );
  }

  Future<void> reconcile() {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  Future<void> setKeepAwake(bool enabled) {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  Future<void> startTunnel() {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  Future<void> stopTunnel() {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  Future<void> startProcess(String name) {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  Future<void> stopProcess(String name) {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  Future<void> restartProcess(String name) {
    return Future<void>.error(UnsupportedError('desktop daemon control is unavailable'));
  }

  void close() {}
}
