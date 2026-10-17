# Plugins

Detection, OCR, translation and inpainting are plugins. Interfaces live in
`packages/ct_core/lib/src/plugins/`, implementations in `packages/ct_providers`
(from M2) or in a platform package such as `ct_ocr_windows` when native code is
involved.

## Interfaces

| Kind | Interface | Method |
|---|---|---|
| `detector` | `TextDetector` | `detect(RgbImage, PluginContext) → List<TextBlock>` |
| `ocr` | `OcrEngine` | `recognize(RgbImage, blocks, sourceLanguage:, context:)` fills `TextBlock.text` |
| `translator` | `Translator` | `translate(TranslationRequest, PluginContext)` fills `TextBlock.translation` |
| `inpainter` | `Inpainter` | `inpaint(RgbImage, GrayImage mask, InpaintConfig, PluginContext) → RgbImage` |

Every instance also implements `dispose()` to release native resources.
`PluginContext` carries the event log (with page/stage context), a
`CancelToken` and, in test mode, the `RunRecorder` for extra artifacts.

## Description: `PluginInfo`

| Field | Meaning |
|---|---|
| `id` | Stable identifier stored in settings and logs, e.g. `openai_compatible` |
| `displayName`, `description` | Shown in the UI |
| `kind` | `detector`, `ocr`, `translator`, `inpainter` |
| `privacy` | `local` (nothing leaves the device), `lan` (local network), `cloud` (internet) |
| `platforms` | Platforms where it works |
| `settings` | Settings schema (`TextSetting`, `SecretSetting`, `ChoiceSetting`, `IntSetting`, `DoubleSetting`, `BoolSetting`); the settings page is generated from it |
| `models` | Ids from `ModelCatalog` that must be downloaded first |

Values are resolved with `PluginConfig.resolve(schema, stored, secrets:)`: types are
coerced, ranges clamped, unknown keys dropped. `SecretSetting` values never reach
`settings.json`; they are stored in the OS secure storage under
`plugin.<pluginId>.<key>` and masked in all diagnostics.

## Adding a provider

1. Create one file, e.g. `packages/ct_providers/lib/src/translation/my_provider.dart`:

   ```dart
   const myProviderInfo = PluginInfo(
     id: 'my_provider',
     displayName: 'My provider',
     kind: PluginKind.translator,
     privacy: Privacy.cloud,
     settings: [
       TextSetting(key: 'url', label: 'API URL', isUrl: true),
       SecretSetting(key: 'api_key', label: 'API key'),
     ],
   );

   final myProviderFactory = PluginFactory<Translator>(
     myProviderInfo,
     (config, env) async => MyProvider(config),
   );
   ```

2. Add one line to `packages/ct_providers/lib/registry.dart`:
   `registry.register(myProviderFactory);`
3. Add tests next to it. Network providers are tested against a local fake
   server; tests must not need real keys or internet access.

The registry caches one live instance per plugin and configuration, and
releases the old one when the configuration changes.
