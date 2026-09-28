import 'dart:convert';
import 'dart:io';

import 'daemon_models.dart';

const int _maxResponseBytes = 1024 * 1024;
const int _maxTokenFileBytes = 4096;
const Duration _requestTimeout = Duration(seconds: 5);
const String _defaultBaseUrl = 'http://127.0.0.1:8770';

class DesktopDaemonClient {
  DesktopDaemonClient({String? baseUrl, String? tokenFile})
      : baseUrl = _validatedLoopbackUrl(
          baseUrl ??
              Platform.environment['GIW_DESKTOP_DAEMON_URL'] ??
              _defaultBaseUrl,
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
    final json = await _request('/v1/status');
    return DesktopDaemonStatus.fromJson(json);
  }

  void close() {
    _http.close(force: false);
  }

  Future<Map<String, dynamic>> _request(String path) async {
    _ensureSupported();
    final token = await _readToken();
    final uri = Uri.parse(baseUrl).resolve(path);
    final request = await _http.getUrl(uri).timeout(_requestTimeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(_requestTimeout);
    if (response.isRedirect) {
      throw StateError('GIW desktop daemon redirects are forbidden');
    }

    final responseBytes = <int>[];
    await for (final chunk in response.timeout(_requestTimeout)) {
      if (responseBytes.length + chunk.length > _maxResponseBytes) {
        throw StateError(
          'GIW desktop daemon response exceeded $_maxResponseBytes bytes',
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

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(responseBytes));
    } on FormatException {
      throw StateError('GIW desktop daemon returned invalid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw StateError('GIW desktop daemon returned non-object JSON');
    }
    return decoded;
  }

  Future<String> _readToken() async {
    final type = await FileSystemEntity.type(tokenFile, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw StateError(
        'GIW desktop daemon token must be a regular non-symlink file',
      );
    }
    final source = File(tokenFile);
    final length = await source.length();
    if (length <= 0 || length > _maxTokenFileBytes) {
      throw StateError(
        'GIW desktop daemon token file must contain 1-$_maxTokenFileBytes bytes',
      );
    }
    final token = (await source.readAsString()).trim();
    if (token.length < 32 ||
        token.length > _maxTokenFileBytes ||
        token.contains(RegExp(r'\s'))) {
      throw StateError('GIW desktop daemon token is malformed');
    }
    return token;
  }

  void _ensureSupported() {
    if (!supported) {
      throw UnsupportedError(
        'GIW desktop daemon status is available only on macOS, Linux, and Windows',
      );
    }
  }
}

String _defaultTokenFile() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) {
    return '.indiebuild${Platform.pathSeparator}daemon${Platform.pathSeparator}token';
  }
  return '$home${Platform.pathSeparator}.indiebuild${Platform.pathSeparator}daemon${Platform.pathSeparator}token';
}

String _validatedLoopbackUrl(String raw) {
  final uri = Uri.parse(raw);
  final authorityMatch = RegExp(
    r'^(?:127\.0\.0\.1|\[::1\]):([0-9]{1,5})$',
  ).firstMatch(uri.authority);
  final port = authorityMatch == null
      ? null
      : int.tryParse(authorityMatch.group(1) ?? '');
  final valid = uri.scheme == 'http' &&
      authorityMatch != null &&
      port != null &&
      port >= 1 &&
      port <= 65535 &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty;
  if (!valid) {
    throw ArgumentError.value(
      raw,
      'baseUrl',
      'GIW desktop daemon URL must be credential-free literal-loopback HTTP with an explicit port and no path, query, or fragment',
    );
  }
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}
