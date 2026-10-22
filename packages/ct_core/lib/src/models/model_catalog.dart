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

  static const ppocrRecEn = ModelSpec(
    id: 'ppocr-v5-rec-en',
    displayName: 'PP-OCRv5 recognizer, English',
    purpose: 'OCR for English',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/ppocr-v5-onnx',
    files: [
      ModelFile(
        name: 'en_PP-OCRv5_rec_mobile_infer.onnx',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/en_PP-OCRv5_rec_mobile_infer.onnx',
        sha256: 'c3461add59bb4323ecba96a492ab75e06dda42467c9e3d0c18db5d1d21924be8',
        size: 7872351,
      ),
      ModelFile(
        name: 'ppocrv5_en_dict.txt',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/ppocrv5_en_dict.txt',
        sha256: 'e025a66d31f327ba0c232e03f407ae8d105e1e709e7ccb3f408aa778c24e70d6',
        size: 1416,
      ),
    ],
  );

  static const ppocrRecLatin = ModelSpec(
    id: 'ppocr-v5-rec-latin',
    displayName: 'PP-OCRv5 recognizer, Latin script',
    purpose: 'OCR for French, German, Spanish, Italian, Dutch',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/ppocr-v5-onnx',
    files: [
      ModelFile(
        name: 'latin_PP-OCRv5_rec_mobile_infer.onnx',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/latin_PP-OCRv5_rec_mobile_infer.onnx',
        sha256: 'b20bd37c168a570f583afbc8cd7925603890efbcdc000a59e22c269d160b5f5a',
        size: 7904513,
      ),
      ModelFile(
        name: 'ppocrv5_latin_dict.txt',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/ppocrv5_latin_dict.txt',
        sha256: '3c0a8a79b612653c25f765271714f71281e4e955962c153e272b7b8c1d2b13ff',
        size: 1634,
      ),
    ],
  );

  static const ppocrRecEslav = ModelSpec(
    id: 'ppocr-v5-rec-eslav',
    displayName: 'PP-OCRv5 recognizer, East Slavic',
    purpose: 'OCR for Russian',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/ppocr-v5-onnx',
    files: [
      ModelFile(
        name: 'eslav_PP-OCRv5_rec_mobile_infer.onnx',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/eslav_PP-OCRv5_rec_mobile_infer.onnx',
        sha256: '08705d6721849b1347d26187f15a5e362c431963a2a62bfff4feac578c489aab',
        size: 7911802,
      ),
      ModelFile(
        name: 'ppocrv5_eslav_dict.txt',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/ppocrv5_eslav_dict.txt',
        sha256: '3e95f1581557162870cacdba5af91a4c6be2890710d395b0c3c7578e7ee5e6eb',
        size: 1663,
      ),
    ],
  );

  static const ppocrRecKorean = ModelSpec(
    id: 'ppocr-v5-rec-korean',
    displayName: 'PP-OCRv5 recognizer, Korean',
    purpose: 'OCR for Korean',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/ppocr-v5-onnx',
    files: [
      ModelFile(
        name: 'korean_PP-OCRv5_rec_mobile_infer.onnx',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/korean_PP-OCRv5_rec_mobile_infer.onnx',
        sha256: 'cd6e2ea50f6943ca7271eb8c56a877a5a90720b7047fe9c41a2e541a25773c9b',
        size: 13488748,
      ),
      ModelFile(
        name: 'ppocrv5_korean_dict.txt',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/ppocrv5_korean_dict.txt',
        sha256: 'a88071c68c01707489baa79ebe0405b7beb5cca229f4fc94cc3ef992328802d7',
        size: 47451,
      ),
    ],
  );

  static const ppocrRecChinese = ModelSpec(
    id: 'ppocr-v6-rec-small',
    displayName: 'PP-OCRv6 recognizer (small), Chinese and Japanese',
    purpose: 'OCR for Chinese',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/ppocr-v6-onnx',
    files: [
      ModelFile(
        name: 'PP-OCRv6_small_rec.onnx',
        url: 'https://huggingface.co/ogkalu/ppocr-v6-onnx/resolve/main/PP-OCRv6_small_rec.onnx',
        sha256: '5435fd747c9e0efe15a96d0b378d5bd157e9492ed8fd80edf08f30d02fa24634',
        size: 21159378,
      ),
      ModelFile(
        name: 'PP-OCRv6_small_rec.txt',
        url: 'https://huggingface.co/ogkalu/ppocr-v6-onnx/resolve/main/PP-OCRv6_small_rec.txt',
        sha256: 'b5f2bfe2bdd9448429e3e82b51c789775d9b42f2403d082b00662eb77e401c5d',
        size: 74947,
      ),
    ],
  );

  static const mangaOcr = ModelSpec(
    id: 'manga-ocr-mobile',
    displayName: 'manga-ocr (mobile ONNX)',
    purpose: 'OCR for Japanese',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/manga-ocr-mobile',
    files: [
      ModelFile(
        name: 'encoder.onnx',
        url: 'https://huggingface.co/ogkalu/manga-ocr-mobile/resolve/main/encoder.onnx',
        sha256: 'd1fb455a07c1508cc56a4f4e15e2ed74aca9a4d78fd220ecc0ff39625d67e1b3',
        size: 17070003,
      ),
      ModelFile(
        name: 'decoder_init.onnx',
        url: 'https://huggingface.co/ogkalu/manga-ocr-mobile/resolve/main/decoder_init.onnx',
        sha256: '612f97e22848620fb36fcac611467689cb4213d91f2d84f6a19042ad57d475f1',
        size: 24875052,
      ),
      ModelFile(
        name: 'decoder_step.onnx',
        url: 'https://huggingface.co/ogkalu/manga-ocr-mobile/resolve/main/decoder_step.onnx',
        sha256: 'a244b814a3a669190f9eae737960997633597cfa055fa186347e872bee834bc9',
        size: 22776797,
      ),
      ModelFile(
        name: 'vocab.txt',
        url: 'https://huggingface.co/ogkalu/manga-ocr-mobile/resolve/main/vocab.txt',
        sha256: '879d9a69df070dbdf143f64bb3daf73d367741980f18a2f6d08a12e68a598a11',
        size: 37193,
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

  static const ppocrDet = ModelSpec(
    id: 'ppocr-v5-det-mobile',
    displayName: 'PP-OCRv5 text line detector (mobile)',
    purpose: 'Text line detection for screenshots, sites and games',
    license: 'Apache-2.0',
    homepage: 'https://huggingface.co/ogkalu/ppocr-v5-onnx',
    files: [
      ModelFile(
        name: 'ch_PP-OCRv5_mobile_det.onnx',
        url: 'https://huggingface.co/ogkalu/ppocr-v5-onnx/resolve/main/ch_PP-OCRv5_mobile_det.onnx',
        sha256: '4d97c44a20d30a81aad087d6a396b08f786c4635742afc391f6621f5c6ae78ae',
        size: 4819576,
      ),
    ],
  );

  static const opusMtEnRu = ModelSpec(
    id: 'opus-mt-en-ru',
    displayName: 'OPUS-MT translator, English to Russian',
    purpose: 'Offline translation from English to Russian',
    license: 'CC-BY-4.0',
    homepage: 'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru',
    files: [
      ModelFile(
        name: 'source.spm',
        url: 'https://huggingface.co/Xenova/opus-mt-en-ru/resolve/main/source.spm',
        sha256: '16bebef1389a0b8ab452772c4e35b9e605e5713f8ac7baa71ca701394eaa086d',
        size: 802781,
      ),
      ModelFile(
        name: 'vocab.json',
        url: 'https://huggingface.co/Xenova/opus-mt-en-ru/resolve/main/vocab.json',
        sha256: '5cf0d95d930d8d3e783c9e2f46a72f08b43a18060dab4ddefbcb66a733efedcb',
        size: 2726796,
      ),
      ModelFile(
        name: 'encoder_model_quantized.onnx',
        url: 'https://huggingface.co/Xenova/opus-mt-en-ru/resolve/main/onnx/encoder_model_quantized.onnx',
        sha256: '97f28d8295d231b7da721ded06fa8c034787df2122cd8f85b904abdc4d15bd53',
        size: 51628446,
      ),
      ModelFile(
        name: 'decoder_model_merged_quantized.onnx',
        url: 'https://huggingface.co/Xenova/opus-mt-en-ru/resolve/main/onnx/decoder_model_merged_quantized.onnx',
        sha256: '7efefcd793a5663bc204224a92a123524f3dfe2ffad59e5f73d6734d1b11ad04',
        size: 58931576,
      ),
    ],
  );

  static const opusMtRuEn = ModelSpec(
    id: 'opus-mt-ru-en',
    displayName: 'OPUS-MT translator, Russian to English',
    purpose: 'Offline translation from Russian to English',
    license: 'CC-BY-4.0',
    homepage: 'https://huggingface.co/Helsinki-NLP/opus-mt-ru-en',
    files: [
      ModelFile(
        name: 'source.spm',
        url: 'https://huggingface.co/Xenova/opus-mt-ru-en/resolve/main/source.spm',
        sha256: '745998e51ba5b058e38b7ac7765c25c43ed5c1c39cc92b27163b9b2e323c9d7c',
        size: 1080169,
      ),
      ModelFile(
        name: 'vocab.json',
        url: 'https://huggingface.co/Xenova/opus-mt-ru-en/resolve/main/vocab.json',
        sha256: '5cf0d95d930d8d3e783c9e2f46a72f08b43a18060dab4ddefbcb66a733efedcb',
        size: 2726796,
      ),
      ModelFile(
        name: 'encoder_model_quantized.onnx',
        url: 'https://huggingface.co/Xenova/opus-mt-ru-en/resolve/main/onnx/encoder_model_quantized.onnx',
        sha256: 'c10df0466540534bb70c4402d539c349b8bfa9968184cad89f51408cf13e7eb7',
        size: 51628446,
      ),
      ModelFile(
        name: 'decoder_model_merged_quantized.onnx',
        url: 'https://huggingface.co/Xenova/opus-mt-ru-en/resolve/main/onnx/decoder_model_merged_quantized.onnx',
        sha256: '25e7ff97b201bce64ab9c39749761d657b70b8602bcbc1ce01c67f713e90ffdf',
        size: 58931576,
      ),
    ],
  );

  static const all = [
    rtdetrV2,
    ppocrDet,
    opusMtEnRu,
    opusMtRuEn,
    ppocrRecEn,
    ppocrRecLatin,
    ppocrRecEslav,
    ppocrRecKorean,
    ppocrRecChinese,
    mangaOcr,
    aot,
    lamaManga,
    osdScript,
  ];

  static ModelSpec? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
