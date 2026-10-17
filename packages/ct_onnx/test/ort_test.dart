import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ct_onnx/ct_onnx.dart';
import 'package:ct_onnx/src/ort.dart' show decodeNativeMessage;
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

String fixture(String name) => '${Directory.current.path}/test/fixtures/$name';

void main() {
  test('runtime loads the pinned version with CPU (and DirectML on Windows)', () {
    final rt = OrtRuntime.instance;
    expect(rt.version, OrtNativeRelease.version);
    expect(rt.availableProviders, contains('CPUExecutionProvider'));
    if (Platform.isWindows) expect(rt.hasDirectML, isTrue);
  });

  test('session metadata', () {
    final s = OrtSession.open(fixture('add.onnx'));
    addTearDown(s.dispose);
    expect(s.device, OrtDevice.cpu);
    expect(s.inputs.map((i) => i.name), ['A', 'B']);
    expect(s.inputs.first.type, OrtElementType.float32);
    expect(s.inputs.first.shape, [-1, 3]);
    expect(s.outputs.single.name, 'C');
  });

  test('float add with a dynamic dimension', () {
    final s = OrtSession.open(fixture('add.onnx'));
    addTearDown(s.dispose);
    final a = OrtTensor.float32(Float32List.fromList([1, 2, 3, 4, 5, 6]), [2, 3]);
    final b = OrtTensor.float32(Float32List.fromList([10, 20, 30, 40, 50, 60]), [2, 3]);
    final out = s.run({'A': a, 'B': b})['C']!;
    expect(out.shape, [2, 3]);
    expect(out.asFloat32, [11, 22, 33, 44, 55, 66]);
  });

  test('int64, float and uint8 outputs', () {
    final s = OrtSession.open(fixture('cast.onnx'));
    addTearDown(s.dispose);
    final out = s.run({
      'X': OrtTensor.int64(Int64List.fromList([1, 2, 3, 4]), [2, 2]),
      'U': OrtTensor.uint8(Uint8List.fromList([0, 127, 200, 255]), [4]),
    });
    expect(out['Y']!.asFloat32, [0.5, 1.0, 1.5, 2.0]);
    expect(out['Z']!.asInt64, [2, 3, 4, 5]);
    expect(out['V']!.asUint8, [0, 127, 200, 255]);

    final onlyZ = s.run({
      'X': OrtTensor.int64(Int64List.fromList([0, 0, 0, 0]), [2, 2]),
      'U': OrtTensor.uint8(Uint8List(4), [4]),
    }, outputNames: ['Z']);
    expect(onlyZ.keys, ['Z']);
  });

  test('errors become OrtException', () {
    final s = OrtSession.open(fixture('add.onnx'));
    addTearDown(s.dispose);
    final a = OrtTensor.float32(Float32List(6), [2, 3]);
    expect(() => s.run({'A': a}), throwsA(isA<OrtException>()), reason: 'missing input B');
    expect(() => OrtSession.open(fixture('missing.onnx')), throwsArgumentError);
  });

  test('embedded self-test model matches the fixture and runs', () async {
    final r = await OrtSelfTest.run();
    expect(r.error, isNull);
    expect(r.cpuOk, isTrue);
    expect(r.version, OrtNativeRelease.version);
    printOnFailure(r.toJson().toString());
  });

  test('native messages in a non-UTF-8 code page do not throw', () {
    // "Ошибка" in cp1251, as Windows reports system errors on Russian systems.
    final bytes = [0xCE, 0xF8, 0xE8, 0xE1, 0xEA, 0xE0, 0x3A, 0x20, 0x44, 0x4D, 0x4C, 0];
    final ptr = calloc<Uint8>(bytes.length);
    addTearDown(() => calloc.free(ptr));
    ptr.asTypedList(bytes.length).setAll(0, bytes);
    final text = decodeNativeMessage(ptr);
    expect(text, endsWith(': DML'));
    expect(text, contains('�'));
  });

  test('tensor shape must match data', () {
    expect(() => OrtTensor.float32(Float32List(5), [2, 3]), throwsArgumentError);
  });

  test('DirectML session works or falls back to CPU with a reason', () {
    final s = OrtSession.open(fixture('add.onnx'), device: OrtDevice.directml);
    addTearDown(s.dispose);
    if (s.device == OrtDevice.cpu) {
      expect(s.fallbackReason, isNotNull);
      printOnFailure('DirectML fallback: ${s.fallbackReason}');
    }
    final a = OrtTensor.float32(Float32List.fromList([1, 1, 1]), [1, 3]);
    final out = s.run({'A': a, 'B': a})['C']!;
    expect(out.asFloat32, [2, 2, 2]);
  });
}
