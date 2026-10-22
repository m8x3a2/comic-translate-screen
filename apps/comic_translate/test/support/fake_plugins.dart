/// Plugins that need no models, for pipeline and GUI tests.
library;

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';

/// Settings that select the fake plugins and the offline mock translator.
AppSettings fakeSettings() =>
    AppSettings(detector: 'fake_det', ocr: 'fake_ocr', translator: 'mock', inpainter: 'fake_inpaint');

PluginInfo fakeInfo(String id, PluginKind kind) =>
    PluginInfo(id: id, displayName: id, kind: kind, privacy: Privacy.local);

class _FakeDetector implements TextDetector {
  _FakeDetector({this.delay = Duration.zero});

  final Duration delay;

  @override
  PluginInfo get info => fakeInfo('fake_det', PluginKind.detector);

  @override
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context) async {
    await Future<void>.delayed(delay);
    return [TextBlock(xyxy: const BBox(10, 10, 90, 40), bubbleXyxy: const BBox(5, 5, 95, 45))];
  }

  @override
  Future<void> dispose() async {}
}

class _FakeOcr implements OcrEngine {
  @override
  PluginInfo get info => fakeInfo('fake_ocr', PluginKind.ocr);

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    context.log.info('fake_ocr_ran');
    for (final b in blocks) {
      b.text = 'HELLO';
    }
  }

  @override
  Future<void> dispose() async {}
}

class _FakeInpainter implements Inpainter {
  @override
  PluginInfo get info => fakeInfo('fake_inpaint', PluginKind.inpainter);

  @override
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context) async =>
      image.clone();

  @override
  Future<void> dispose() async {}
}

PluginRegistry fakeRegistryWith({Duration detectDelay = Duration.zero}) => PluginRegistry()
  ..register(
    PluginFactory<TextDetector>(
      fakeInfo('fake_det', PluginKind.detector),
      (c, e) async => _FakeDetector(delay: detectDelay),
    ),
  )
  ..register(PluginFactory<OcrEngine>(fakeInfo('fake_ocr', PluginKind.ocr), (c, e) async => _FakeOcr()))
  ..register(PluginFactory<Inpainter>(fakeInfo('fake_inpaint', PluginKind.inpainter), (c, e) async => _FakeInpainter()))
  ..register(chatOcrFactory)
  ..register(chatTranslatorFactory)
  ..register(mockTranslatorFactory)
  ..register(
    PluginFactory<Translator>(fakeInfo('fake_fail', PluginKind.translator), (c, e) async => _FailingTranslator()),
  )
  ..register(PluginFactory<Translator>(fakeCloudInfo, (c, e) async => _FailingTranslator()))
  ..register(
    PluginFactory<Translator>(
      const PluginInfo(
        id: 'fake_no_address',
        displayName: 'No address',
        kind: PluginKind.translator,
        privacy: Privacy.cloud,
        endpoint: _noAddress,
      ),
      (c, e) async => _FailingTranslator(),
    ),
  )
  ..register(
    PluginFactory<Translator>(
      fakeInfo('fake_bad_reply', PluginKind.translator),
      (c, e) async => _FailingTranslator(TranslationErrorKind.badReply),
    ),
  );

/// A translator on an internet service that needs a key.
const fakeCloudInfo = PluginInfo(
  id: 'fake_cloud',
  displayName: 'Cloud translator',
  kind: PluginKind.translator,
  privacy: Privacy.cloud,
  settings: [SecretSetting(key: 'api_key', label: 'API key')],
  endpoint: _cloudEndpoint,
);

PluginEndpoint _cloudEndpoint(PluginConfig config) => const PluginEndpoint(Privacy.cloud, 'cloud.example');

/// An internet translator whose server address is not set.
PluginEndpoint _noAddress(PluginConfig config) => const PluginEndpoint(Privacy.cloud, '');

/// Fails every page as an out-of-credit server would.
class _FailingTranslator implements Translator {
  _FailingTranslator([this.kind = TranslationErrorKind.credits]);

  final TranslationErrorKind kind;
  @override
  PluginInfo get info => fakeInfo('fake_fail', PluginKind.translator);

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async =>
      throw TranslationException('example.com answered HTTP 402: insufficient credits', kind: kind, statusCode: 402);

  @override
  Future<void> dispose() async {}
}

PluginRegistry fakeRegistry() => fakeRegistryWith();
PluginRegistry slowFakeRegistry() => fakeRegistryWith(detectDelay: const Duration(milliseconds: 300));
