import 'package:flutter/material.dart';

import 'api/models.dart';
import 'desktop/daemon_client.dart';
import 'desktop/daemon_models.dart';
import 'widgets/status_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage> {
  late final DesktopDaemonClient _daemon;
  DesktopDaemonStatus? _desktopStatus;
  String? _desktopError;

  @override
  void initState() {
    super.initState();
    _daemon = DesktopDaemonClient();
    if (_daemon.supported) {
      _refreshDesktop();
    }
  }

  @override
  void dispose() {
    _daemon.close();
    super.dispose();
  }

  Future<void> _refreshDesktop() async {
    try {
      final status = await _daemon.status();
      if (!mounted) {
        return;
      }
      setState(() {
        _desktopStatus = status;
        _desktopError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _desktopError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const hostedStatus = ConnectionStatus(
      connected: false,
      endpoint: 'https://indiebuild.dev',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('IndieBuild')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const StatusCard(status: hostedStatus),
          const SizedBox(height: 24),
          _buildDesktopPanel(context),
        ],
      ),
    );
  }

  Widget _buildDesktopPanel(BuildContext context) {
    if (!_daemon.supported) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Local GIW daemon status is available on macOS, Linux, and Windows desktop builds.',
          ),
        ),
      );
    }

    final status = _desktopStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Local execution status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refreshDesktop,
                  tooltip: 'Refresh daemon status',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Read-only view of the GIW desktop daemon. Execution remains owned by the daemon and delegated to Scintilla.',
            ),
            if (_desktopError != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _desktopError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (status == null) ...<Widget>[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              Text('Product: ${status.product}'),
              Text('Execution backend: ${status.executionBackend}'),
              Text('Isolation: ${status.isolation}'),
              Text('Worker reuse: ${status.workerReuse}'),
              Text(
                'Dispatches: ${status.inFlightDispatches}/${status.maxInFlightDispatches}',
              ),
              Text('Uptime: ${status.uptimeMs} ms'),
            ],
          ],
        ),
      ),
    );
  }
}
