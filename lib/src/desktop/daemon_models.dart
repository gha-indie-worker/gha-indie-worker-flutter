class DesktopProcessStatus {
  const DesktopProcessStatus({
    required this.name,
    required this.running,
    required this.pid,
  });

  final String name;
  final bool running;
  final int? pid;

  factory DesktopProcessStatus.fromJson(Map<String, dynamic> json) {
    return DesktopProcessStatus(
      name: json['name'] as String,
      running: json['running'] as bool,
      pid: json['pid'] as int?,
    );
  }
}

class DesktopTunnelStatus {
  const DesktopTunnelStatus({
    required this.name,
    required this.hostname,
    required this.serviceUrl,
    required this.running,
    required this.pid,
  });

  final String name;
  final String? hostname;
  final String serviceUrl;
  final bool running;
  final int? pid;

  factory DesktopTunnelStatus.fromJson(Map<String, dynamic> json) {
    return DesktopTunnelStatus(
      name: json['name'] as String,
      hostname: json['hostname'] as String?,
      serviceUrl: json['service_url'] as String,
      running: json['running'] as bool,
      pid: json['pid'] as int?,
    );
  }
}

class DesktopDaemonStatus {
  const DesktopDaemonStatus({
    required this.protocolVersion,
    required this.mode,
    required this.bind,
    required this.manifestVersion,
    required this.services,
    required this.tunnel,
    required this.keepAwake,
  });

  final int protocolVersion;
  final String mode;
  final String bind;
  final int manifestVersion;
  final List<DesktopProcessStatus> services;
  final DesktopTunnelStatus? tunnel;
  final bool keepAwake;

  factory DesktopDaemonStatus.fromJson(Map<String, dynamic> json) {
    final servicesJson = json['services'] as List<dynamic>? ?? const <dynamic>[];
    final tunnelJson = json['tunnel'];

    return DesktopDaemonStatus(
      protocolVersion: json['protocol_version'] as int,
      mode: json['mode'] as String,
      bind: json['bind'] as String,
      manifestVersion: json['manifest_version'] as int,
      services: servicesJson
          .map((entry) => DesktopProcessStatus.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      tunnel: tunnelJson == null
          ? null
          : DesktopTunnelStatus.fromJson(tunnelJson as Map<String, dynamic>),
      keepAwake: json['keep_awake'] as bool,
    );
  }
}
