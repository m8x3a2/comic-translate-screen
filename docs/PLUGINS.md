# Plugins

> The plugin interfaces land in milestone M1. This page describes the contract they
> will follow; it is updated together with the code.

Detection, OCR, translation, inpainting and text rendering are plugins. Interfaces
live in `packages/ct_core`, implementations in `packages/ct_providers` (or in a
platform package such as `ct_ocr_windows` when native code is involved).

## Contract

Every plugin exposes a `PluginInfo`:

| Field | Meaning |
|---|---|
| `id` | Stable identifier stored in settings and logs, e.g. `openai_compatible` |
| `displayName` | Name shown in the UI |
| `kind` | `detector`, `ocr`, `translator`, `inpainter`, `renderer` |
| `privacy` | `local` (nothing leaves the device), `lan` (local network), `cloud` (internet) |
| `platforms` | Platforms where it works |
| `settings` | Settings schema; the settings page is generated from it. Fields marked secret are stored in secure storage |
| `models` | Models to download before first use (URL, size, SHA-256, license) |

## Adding a provider

1. Create one file, e.g. `packages/ct_providers/lib/src/translation/my_provider.dart`,
   implementing the interface for its kind.
2. Add one line to `packages/ct_providers/lib/registry.dart`.
3. Add tests next to it. Network providers are tested against a local fake server;
   tests must not need real keys or internet access.

Providers that send data out of the device must declare `privacy: cloud` (or `lan`);
the UI marks them and asks the user before first use.
