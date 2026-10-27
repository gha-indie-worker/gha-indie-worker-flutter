class DesktopDaemonStatus {
  const DesktopDaemonStatus({
    required this.product,
    required this.executionBackend,
    required this.isolation,
    required this.workerReuse,
    required this.inFlightDispatches,
    required this.maxInFlightDispatches,
    required this.uptimeMs,
    required this.scintilla,
  });

  final String product;
  final String executionBackend;
  final String isolation;
  final String workerReuse;
  final int inFlightDispatches;
  final int maxInFlightDispatches;
  final int uptimeMs;
  final Map<String, dynamic> scintilla;

  factory DesktopDaemonStatus.fromJson(Map<String, dynamic> json) {
    return DesktopDaemonStatus(
      product: json['product'] as String,
      executionBackend: json['execution_backend'] as String,
      isolation: json['isolation'] as String,
      workerReuse: json['worker_reuse'] as String,
      inFlightDispatches: json['in_flight_dispatches'] as int,
      maxInFlightDispatches: json['max_in_flight_dispatches'] as int,
      uptimeMs: json['uptime_ms'] as int,
      scintilla: Map<String, dynamic>.from(
        json['scintilla'] as Map<dynamic, dynamic>,
      ),
    );
  }
}
