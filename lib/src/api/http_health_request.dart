import 'dart:async';
import 'dart:typed_data';

import 'package:gha_indie_worker_client/gha_indie_worker_client.dart';
import 'package:http/http.dart' as http;

final class HttpHealthRequest {
  Stream<Uint8List> call(String endpoint) {
    final client = http.Client();
    late final StreamController<Uint8List> controller;

    Future<void> perform() async {
      try {
        final response = await client.get(Uri.parse(endpoint));
        if (controller.isClosed) {
          return;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          controller.addError(
            const ClientException(ClientErrorCode.http),
            StackTrace.current,
          );
        } else {
          controller.add(Uint8List.fromList(response.bodyBytes));
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(asClientException(error), stackTrace);
        }
      } finally {
        client.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    controller = StreamController<Uint8List>(
      onListen: () => unawaited(perform()),
      onCancel: () {
        client.close();
        if (!controller.isClosed) {
          return controller.close();
        }
        return null;
      },
    );
    return controller.stream;
  }
}
