import 'package:flutter/widgets.dart';
import 'package:gha_indie_worker_client/gha_indie_worker_client.dart';
import 'package:gha_indie_worker_flutter/src/app.dart';
import 'package:gha_indie_worker_flutter/src/api/http_health_request.dart';

void main() {
  const baseUrl = String.fromEnvironment(
    'GHA_INDIE_WORKER_API_BASE',
    defaultValue: 'http://127.0.0.1:8080',
  );
  final client = Client(const ClientConfig(baseUrl: baseUrl));
  final request = HttpHealthRequest();

  runApp(GhaIndieWorkerApp(client: client, request: request.call));
}
