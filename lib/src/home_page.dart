import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gha_indie_worker_client/gha_indie_worker_client.dart';

import 'widgets/status_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.client,
    required this.request,
  });

  final Client client;
  final HealthRequest request;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final StreamController<void> _refresh;
  late final Stream<HealthProbeState> _states;

  @override
  void initState() {
    super.initState();
    _refresh = StreamController<void>();
    _states = observeHealth(
      triggers: _refresh.stream,
      client: widget.client,
      request: widget.request,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  void _probe() {
    if (mounted && !_refresh.isClosed) {
      _refresh.add(null);
    }
  }

  @override
  void dispose() {
    unawaited(_refresh.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GHA Indie Worker')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<HealthProbeState>(
          stream: _states,
          initialData: HealthChecking(widget.client.healthUrl()),
          builder: (context, snapshot) => StatusCard(
            status: snapshot.requireData,
            onRefresh: _probe,
          ),
        ),
      ),
    );
  }
}
