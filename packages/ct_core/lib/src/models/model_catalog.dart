/// One downloadable file of a model.
class ModelFile {
  const ModelFile({required this.name, required this.url, required this.sha256, required this.size});

  final String name;
  final String url;

  /// Lower-case hex SHA-256 of the file.
  final String sha256;

  /// Size in bytes (shown to the user before downloading).
  final int size;

  String get host => Uri.parse(url).host;
}

/// A model the app can download. URLs and checksums come from the original
/// `modules/utils/download.py`.
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.displayName,
    required this.purpose,
    required this.files,
    required this.license,
    required this.homepage,
  });

  final String id;
  final String displayName;
  final String purpose;
  final List<ModelFile> files;
  final String license;
  final String homepage;

  int get totalSize => files.fold(0, (sum, f) => sum + f.size);

  /// Hosts data will be requested from (shown in the download prompt).
  Set<String> get hosts => {for (final f in files) f.host};

  ModelFile file(String name) =>
      files.firstWhere((f) => f.name == name, orElse: () => throw ArgumentError('$id has no file $name'));
}

abstract final class ModelCatalog {
  static const rtdetrV2 = ModelSpec(
    id: 'rtdetr-v2-int8',
    displayName: 'RT-DETR-v2 comic text & bubble detector (int8)',
    purpose: 'Text and speech bubble detection',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/comic-text-and-bubble-detector',
    files: [
      ModelFile(
        name: 'detector-v4-s_int8.onnx',
        url: 'https://huggingface.co/ogkalu/comic-text-and-bubble-detector/resolve/main/detector-v4-s_int8.onnx',
        sha256: '5fe9e4f576e49d4e7e8b0e029d6d3cdc252abd4694113e1cae120e62c931ea79',
        size: 11120765,
      ),
    ],
  );

  static const aot = ModelSpec(
    id: 'aot-inpainting',
    displayName: 'AOT-GAN inpainting',
    purpose: 'Text removal (default inpainter)',
    license: 'MIT',
    homepage: 'https://huggingface.co/ogkalu/aot-inpainting',
    files: [
      ModelFile(
        name: 'aot.onnx',
        url: 'https://huggingface.co/ogkalu/aot-inpainting/resolve/main/aot.onnx',
        sha256: 'ffd39ed8e2a275869d3b49180d030f0d8b8b9c2c20ed0e099ecd207201f0eada',
        size: 23068213,
      ),
    ],
  );

  static const lamaManga = ModelSpec(
    id: 'lama-manga',
    displayName: 'LaMa (manga/anime fine-tune)',
    purpose: 'Text removal (higher quality, slower, larger)',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/lama-manga-onnx-dynamic',
    files: [
      ModelFile(
        name: 'lama-manga-dynamic.onnx',
        url: 'https://huggingface.co/ogkalu/lama-manga-onnx-dynamic/resolve/main/lama-manga-dynamic.onnx',
        sha256: 'de31ffa5ba26916b8ea35319f6c12151ff9654d4261bccf0583a69bb095315f9',
        size: 206291843,
      ),
    ],
  );

  static const osdScript = ModelSpec(
    id: 'osd-script-id',
    displayName: 'Script identification (OSD LSTM)',
    purpose: 'Automatic source-language (script) detection',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/image-script-identification',
    files: [
      ModelFile(
        name: 'osd_lstm.onnx',
        url: 'https://huggingface.co/ogkalu/image-script-identification/resolve/main/osd_lstm.onnx',
        sha256: 'b18e0c1479d9eb67394993098f7e1079c9a93ef6f7b0416ee333fccb865c6e72',
        size: 3722314,
      ),
      ModelFile(
        name: 'osd_labels.json',
        url: 'https://huggingface.co/ogkalu/image-script-identification/resolve/main/osd_labels.json',
        sha256: 'a1888156b005065039c356e13a7bbef1ec454b45bf6aaf18c11f4a59b1ee35c5',
        size: 1163,
      ),
    ],
  );

  static const all = [rtdetrV2, aot, lamaManga, osdScript];

  static ModelSpec? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
