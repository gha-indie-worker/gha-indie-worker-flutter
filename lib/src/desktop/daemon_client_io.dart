import 'dart:convert';
import 'dart:io';

import 'daemon_models.dart';

const int _supportedProtocolVersion = 1;
const String _defaultBaseUrl = 'http://127.0.0.1:18440';

class DesktopDaemonClient {
  DesktopDaemonClient({String? baseUrl, String? tokenFile})
      : baseUrl = baseUrl ?? Platform.environment['GIW_DESKTOP_URL'] ?? _defaultBaseUrl,
        tokenFile = tokenFile ??
            Platform.environment['GIW_DESKTOP_TOKEN_FILE'] ??
            _defaultTokenFile(),
        _http = HttpClient() {
    _validateLoopbackUrl(this.baseUrl);
  }

  final String baseUrl;
  final String tokenFile;
  final HttpClient _http;

  bool get supported => Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  Future<DesktopDaemonStatus> status() async {
    final json = await _request('GET', '/v1/status');
    final status = DesktopDaemonStatus.fromJson(json);
    _ensureProtocol(status.protocolVersion);
    return status;
  }

  Future<void> reconcile() async {
    await _request('POST', '/v1/reconcile');
    return;
  }

  Future<void> setKeepAwake(bool enabled) async {
    await _request(
      'POST',
      '/v1/power/keep-awake',
      body: <String, dynamic>{'enabled': enabled},
    );
    return;
  }

  Future<void> startTunnel() async {
    await _request('POST', '/v1/tunnel/start');
    return;
  }

  Future<void> stopTunnel() async {
    await _request('POST', '/v1/tunnel/stop');
    return;
  }

  Future<void> startProcess(String name) async {
    _validateProcessName(name);
    await _request('POST', '/v1/processes/$name/start');
    return;
  }

  Future<void> stopProcess(String name) async {
    _validateProcessName(name);
    await _request('POST', '/v1/processes/$name/stop');
    return;
  }

  Future<void> restartProcess(String name) async {
    _validateProcessName(name);
    await _request('POST', '/v1/processes/$name/restart');
    return;
  }

  void close() {
    _http.close(force: false);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    _ensureSupported();
    final token = (await File(tokenFile).readAsString()).trim();
    if (token.length < 32 || token.contains(RegExp(r'\s'))) {
      throw StateError('GIW desktop daemon token at $tokenFile is malformed');
    }

    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    final HttpClientRequest request;
    if (method == 'GET') {
      request = await _http.getUrl(uri);
    } else if (method == 'POST') {
      request = await _http.postUrl(uri);
    } else {
      throw ArgumentError.value(method, 'method', 'unsupported daemon HTTP method');
    }

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('GIW desktop daemon returned a non-object JSON response');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GIW desktop daemon request failed with ${response.statusCode}: $decoded',
        uri: uri,
      );
    }

    final protocolVersion = decoded['protocol_version'];
    if (protocolVersion is int) {
      _ensureProtocol(protocolVersion);
    }
    return decoded;
  }

  void _ensureSupported() {
    if (!supported) {
      throw UnsupportedError(
        'GIW desktop daemon control is currently supported on macOS, Linux, and Windows desktop targets',
      );
    }
  }
}

String _defaultTokenFile() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) {
    throw StateError('HOME or USERPROFILE must be set to locate the GIW desktop token');
  }
  return '$home${Platform.pathSeparator}.giw${Platform.pathSeparator}desktop${Platform.pathSeparator}token';
}

void _validateLoopbackUrl(String raw) {
  final uri = Uri.parse(raw);
  final loopback = uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1';
  if (uri.scheme != 'http' || !loopback || uri.userInfo.isNotEmpty) {
    throw ArgumentError.value(raw, 'baseUrl', 'GIW desktop daemon URL must be credential-free loopback HTTP');
  }
}

void _validateProcessName(String name) {
  if (name.trim().isEmpty || name.contains('/')) {
    throw ArgumentError.value(name, 'name', 'process name must be a manifest service name without /');
  }
}

void _ensureProtocol(int version) {
  if (version > _supportedProtocolVersion) {
    throw StateError(
      'GIW daemon protocol $version is newer than this Flutter client supports ($_supportedProtocolVersion)',
    );
  }
}
