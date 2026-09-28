import 'package:flutter/material.dart';
import 'package:gha_indie_worker_client/gha_indie_worker_client.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  final HealthProbeState status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final view = switch (status) {
      HealthChecking() => (
          title: 'Checking worker',
          detail: 'Waiting for a health response',
          icon: Icons.sync,
        ),
      HealthAvailable(:final health) => (
          title: health.ok ? 'Worker available' : 'Worker degraded',
          detail: health.service,
          icon: health.ok ? Icons.check_circle : Icons.warning,
        ),
      HealthUnavailable(:final error) => (
          title: 'Worker unavailable',
          detail: error.code.name,
          icon: Icons.error,
        ),
    };

    return Card(
      child: ListTile(
        leading: Icon(view.icon),
        title: Text(view.title),
        subtitle: Text('${status.endpoint}\n${view.detail}'),
        trailing: IconButton(
          key: const Key('refresh-health'),
          tooltip: 'Check again',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
