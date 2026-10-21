import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('adapters from Windows: one or several, PowerShell 5 or 7 dates', () {
    final two = GpuInfo.parse(
      '[{"Name":"NVIDIA GeForce MX150","AdapterRAM":2147483648,"DriverVersion":"26.21.14.4219",'
      '"DriverDate":"\\/Date(1580256000000)\\/"},'
      '{"Name":"Intel(R) UHD Graphics 620","AdapterRAM":1073741824,"DriverVersion":"25.20.100.6444",'
      '"DriverDate":"2018-11-24T00:00:00+00:00"}]',
    );
    expect(two.map((a) => a.name), ['NVIDIA GeForce MX150', 'Intel(R) UHD Graphics 620']);
    expect(two.first.memoryBytes, 2147483648);
    expect(two.first.driverDate!.year, 2020);
    expect(two.last.driverDate!.year, 2018);
    expect([for (final a in two) a.integrated], [false, true]);
    expect(two.first.toJson()['driver_date'], '2020-01-29');

    final one = GpuInfo.parse('{"Name":"Microsoft Basic Display Adapter","AdapterRAM":null}');
    expect(one.single.software, isTrue);
    expect(one.single.memoryBytes, isNull);
    expect(GpuInfo.parse(''), isEmpty);
    expect(GpuAdapter.fromWmi({'Name': ''}), isNull);
    expect(const GpuAdapter(name: 'AMD Radeon(TM) Graphics').integrated, isTrue);
    expect(const GpuAdapter(name: 'AMD Radeon RX 6600').integrated, isFalse);
    expect(const GpuAdapter(name: 'Citrix Indirect Display Adapter').software, isTrue);
    expect(const GpuAdapter(name: 'NVIDIA GeForce GTX 1660 Ti').software, isFalse);
  });
}
