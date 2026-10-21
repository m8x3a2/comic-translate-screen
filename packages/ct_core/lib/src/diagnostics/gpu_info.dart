/// The graphics adapters of this computer, for the GPU setting, `cts doctor`
/// and bug reports. Windows only (WMI through PowerShell); empty elsewhere.
library;

import 'dart:convert';
import 'dart:io';

class GpuAdapter {
  const GpuAdapter({required this.name, this.memoryBytes, this.driverVersion, this.driverDate});

  final String name;

  /// Dedicated memory as Windows reports it (at most 4 GB: the WMI field is
  /// 32-bit).
  final int? memoryBytes;
  final String? driverVersion;
  final DateTime? driverDate;

  /// Windows' own display drivers, remote desktop, virtual machines, screen
  /// sharing and USB display adapters: no graphics card to compute on.
  bool get software {
    final n = name.toLowerCase();
    const marks = [
      'basic display',
      'basic render',
      'remote display',
      'remote desktop',
      'virtual',
      'indirect display',
      'citrix',
      'hyper-v',
      'vmware',
      'virtualbox',
      'parsec',
      'spacedesk',
      'displaylink',
      'mirage driver',
    ];
    return marks.any(n.contains);
  }

  /// Built into the processor (Intel UHD / Iris, AMD Radeon Graphics of
  /// Ryzen processors): rarely faster than the processor itself.
  bool get integrated {
    final n = name.toLowerCase();
    return (n.contains('intel') && (n.contains('uhd') || n.contains('hd graphics') || n.contains('iris'))) ||
        n.contains('radeon(tm) graphics') ||
        n.contains('radeon graphics') ||
        n.contains('radeon vega');
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'memory_bytes': ?memoryBytes,
    'driver_version': ?driverVersion,
    if (driverDate != null) 'driver_date': driverDate!.toIso8601String().substring(0, 10),
  };

  /// One adapter of `Get-CimInstance Win32_VideoController | ConvertTo-Json`.
  static GpuAdapter? fromWmi(Object? json) {
    if (json is! Map) return null;
    final name = json['Name'];
    if (name is! String || name.trim().isEmpty) return null;
    final ram = json['AdapterRAM'];
    final version = json['DriverVersion'];
    return GpuAdapter(
      name: name.trim(),
      memoryBytes: ram is num && ram > 0 ? ram.toInt() : null,
      driverVersion: version is String ? version : null,
      driverDate: _wmiDate(json['DriverDate']),
    );
  }

  /// `/Date(1580256000000)/` (PowerShell 5) or an ISO date (PowerShell 7).
  static DateTime? _wmiDate(Object? v) {
    if (v is! String) return null;
    final ms = RegExp(r'Date\((\d+)').firstMatch(v)?.group(1);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(int.parse(ms), isUtc: true);
    return DateTime.tryParse(v);
  }
}

abstract final class GpuInfo {
  /// The adapters Windows knows; empty when they cannot be listed.
  static Future<List<GpuAdapter>> list() async {
    if (!Platform.isWindows) return const [];
    try {
      final r = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM,DriverVersion,DriverDate | '
            'ConvertTo-Json -Compress',
      ]).timeout(const Duration(seconds: 20));
      if (r.exitCode != 0) return const [];
      return parse(r.stdout as String);
    } on Object {
      return const [];
    }
  }

  /// [json]: one object or a list of them.
  static List<GpuAdapter> parse(String json) {
    final text = json.trim();
    if (text.isEmpty) return const [];
    final decoded = jsonDecode(text);
    final items = decoded is List ? decoded : [decoded];
    return [for (final i in items) ?GpuAdapter.fromWmi(i)];
  }
}
