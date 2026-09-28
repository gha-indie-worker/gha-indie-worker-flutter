import 'dart:convert';
import 'dart:io';

import 'daemon_models.dart';

const int _supportedProtocolVersion = 1;
const int _maxResponseBytes = 1024 * 1024;
const int _maxTokenFileBytes = 4096;
const Duration _requestTimeout = Duration(seconds: 5);
const String _defaultBaseUrl = 'http://127.0.0.1:18440';

class DesktopDaemonClient {
  DesktopDaemonClient({String? baseUrl, String? tokenFile})
      : baseUrl = _validatedLoopbackUrl(
          baseUrl ?? Platform.environment['GIW_DESKTOP_URL'] ?? _defaultBaseUrl,
        ),
        tokenFile = tokenFile ??
            Platform.environment['GIW_DESKTOP_TOKEN_FILE'] ??
            _defaultTokenFile(),
        _http = HttpClient()
          ..connectionTimeout = _requestTimeout
          ..idleTimeout = _requestTimeout;

  final String baseUrl;
  final String tokenFile;
  final HttpClient _http;

  bool get supported =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  Future<DesktopDaemonStatus> status() async {
    final json = await _request('GET', '/v1/status');
    final status = DesktopDaemonStatus.fromJson(json);
    _ensureProtocol(status.protocolVersion);
    return status;
  }

  Future<void> reconcile() async {
    await _request('POST', '/v1/reconcile');
  }

  Future<void> setKeepAwake(bool enabled) async {
    await _request(
      'POST',
      '/v1/power/keep-awake',
      body: <String, dynamic>{'enabled': enabled},
    );
  }

  Future<void> startTunnel() async {
    await _request('POST', '/v1/tunnel/start');
  }

  Future<void> stopTunnel() async {
    await _request('POST', '/v1/tunnel/stop');
  }

  Future<void> startProcess(String name) async {
    _validateProcessName(name);
    await _request('POST', '/v1/processes/$name/start');
  }

  Future<void> stopProcess(String name) async {
    _validateProcessName(name);
    await _request('POST', '/v1/processes/$name/stop');
  }

  Future<void> restartProcess(String name) async {
    _validateProcessName(name);
    await _request('POST', '/v1/processes/$name/restart');
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

    final tokenSource = File(tokenFile);
    final tokenBytes = await tokenSource.length();
    if (tokenBytes <= 0 || tokenBytes > _maxTokenFileBytes) {
      throw StateError(
        'GIW desktop daemon token file must contain 1-$_maxTokenFileBytes bytes',
      );
    }

    final token = (await tokenSource.readAsString()).trim();
    if (token.length < 32 || token.contains(RegExp(r'\s'))) {
      throw StateError('GIW desktop daemon token at $tokenFile is malformed');
    }

    final uri = Uri.parse(baseUrl).resolve(path);
    final HttpClientRequest request;
    if (method == 'GET') {
      request = await _http.getUrl(uri).timeout(_requestTimeout);
    } else if (method == 'POST') {
      request = await _http.postUrl(uri).timeout(_requestTimeout);
    } else {
      throw ArgumentError.value(
        method,
        'method',
        'unsupported daemon HTTP method',
      );
    }

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(_requestTimeout);
    final responseBytes = <int>[];
    await for (final chunk in response.timeout(_requestTimeout)) {
      if (responseBytes.length + chunk.length > _maxResponseBytes) {
        throw StateError(
          'GIW desktop daemon response exceeded the $_maxResponseBytes-byte maximum response size',
        );
      }
      responseBytes.addAll(chunk);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GIW desktop daemon request failed with ${response.statusCode}',
        uri: uri,
      );
    }

    final text = utf8.decode(responseBytes);
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw StateError('GIW desktop daemon returned invalid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'GIW desktop daemon returned a non-object JSON response',
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
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) {
    // Android/iOS are dart:io targets but are not local process supervisors. Keep
    // construction side-effect free there; _ensureSupported() fails before IO.
    return '.giw${Platform.pathSeparator}desktop${Platform.pathSeparator}token';
  }
  return '$home${Platform.pathSeparator}.giw${Platform.pathSeparator}desktop${Platform.pathSeparator}token';
}

String _validatedLoopbackUrl(String raw) {
  final uri = Uri.parse(raw);
  final authorityMatch = RegExp(
    r'^(?:127\.0\.0\.1|\[::1\]):([0-9]{1,5})$',
  ).firstMatch(uri.authority);
  final port = authorityMatch == null
      ? null
      : int.tryParse(authorityMatch.group(1) ?? '');

  final pathIsBaseOnly = uri.path.isEmpty || uri.path == '/';
  final valid = uri.scheme == 'http' &&
      authorityMatch != null &&
      port != null &&
      port >= 1 &&
      port <= 65535 &&
      uri.userInfo.isEmpty &&
      pathIsBaseOnly &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty;

  if (!valid) {
    throw ArgumentError.value(
      raw,
      'baseUrl',
      'GIW desktop daemon URL must be credential-free numeric loopback HTTP with an explicit port and no path, query, or fragment',
    );
  }

  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

void _validateProcessName(String name) {
  final valid = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(name);
  if (!valid || name == '.' || name == '..') {
    throw ArgumentError.value(
      name,
      'name',
      'process name must be a 1-128 character manifest service name using only letters, digits, dot, underscore, and hyphen',
    );
  }
}

void _ensureProtocol(int version) {
  if (version != _supportedProtocolVersion) {
    throw StateError(
      'GIW daemon protocol $version is unsupported; this Flutter client requires $_supportedProtocolVersion',
    );
  }
}
