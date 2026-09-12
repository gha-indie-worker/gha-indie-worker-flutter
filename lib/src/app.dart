import 'package:flutter/material.dart';
import 'package:gha_indie_worker_client/gha_indie_worker_client.dart';

import 'home_page.dart';
import 'theme.dart';

class GhaIndieWorkerApp extends StatelessWidget {
  const GhaIndieWorkerApp({
    super.key,
    required this.client,
    required this.request,
  });

  final Client client;
  final HealthRequest request;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GHA Indie Worker',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: HomePage(client: client, request: request),
    );
  }
}
