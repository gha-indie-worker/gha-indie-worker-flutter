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
  bool _busy = false;

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

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _desktopError = null;
    });
    try {
      await operation();
      await _refreshDesktop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _desktopError = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
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
            'Local GIW daemon controls are shown on macOS, Linux, and Windows desktop builds.',
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
                  'Local desktop control plane',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _busy ? null : _refreshDesktop,
                  tooltip: 'Refresh daemon status',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_desktopError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _desktopError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (status == null) ...<Widget>[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              Text('Mode: ${status.mode} · daemon ${status.bind}'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Keep IndieBuild alive during lock-screen / sleep',
                ),
                value: status.keepAwake,
                onChanged: _busy
                    ? null
                    : (enabled) {
                        _perform(() => _daemon.setKeepAwake(enabled));
                      },
              ),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: _busy ? null : () => _perform(_daemon.reconcile),
                    child: const Text('Reconcile'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                              status.tunnel?.running == true
                                  ? _daemon.stopTunnel
                                  : _daemon.startTunnel,
                            ),
                    child: Text(
                      status.tunnel?.running == true
                          ? 'Stop tunnel'
                          : 'Start tunnel',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final service in status.services) _buildServiceRow(service),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceRow(DesktopProcessStatus service) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(service.name),
      subtitle: Text(
        service.running ? 'running · pid ${service.pid ?? '-'}' : 'stopped',
      ),
      trailing: Wrap(
        spacing: 8,
        children: <Widget>[
          TextButton(
            onPressed: _busy || service.running
                ? null
                : () => _perform(() => _daemon.startProcess(service.name)),
            child: const Text('Start'),
          ),
          TextButton(
            onPressed: _busy || !service.running
                ? null
                : () => _perform(() => _daemon.restartProcess(service.name)),
            child: const Text('Restart'),
          ),
          TextButton(
            onPressed: _busy || !service.running
                ? null
                : () => _perform(() => _daemon.stopProcess(service.name)),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
