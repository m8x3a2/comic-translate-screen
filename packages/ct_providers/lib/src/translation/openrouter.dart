/// OpenRouter (openrouter.ai): one key for hundreds of models, some of them
/// free. The OpenAI-compatible translator with the address and the technical
/// fields set; the user picks a model and puts in a key. Not in the
/// original (there it is the "Custom" translator with OpenRouter's address).
library;

import 'package:ct_core/ct_core.dart';

import 'openai_compatible.dart';

const openRouterApiUrl = 'https://openrouter.ai/api/v1';

const openRouterInfo = PluginInfo(
  id: 'openrouter',
  displayName: 'OpenRouter',
  description: 'Translates with a large language model through OpenRouter (openrouter.ai): one key for hundreds '
      'of models from different companies, some of them free.',
  kind: PluginKind.translator,
  privacy: Privacy.cloud,
  settings: [
    TextSetting(
      key: 'model',
      label: 'Model',
      help: 'Pick one from the list ("Choose…") or type its id.',
      placeholder: 'openai/gpt-4.1-mini',
    ),
    SecretSetting(key: 'api_key', label: 'API key', help: 'Made on openrouter.ai: "Get a key".'),
    llmPagesSetting,
    llmResendSetting,
    llmTemperatureSetting,
    llmMaxTokensSetting,
    llmTimeoutSetting,
  ],
  endpoint: openRouterEndpoint,
  keyStatus: openRouterKeyStatus,
  modelCatalog: openRouterModelCatalog,
  keyUrl: 'https://openrouter.ai/settings/keys',
);

final openRouterFactory = PluginFactory<Translator>(openRouterInfo, (config, env) async {
  return OpenAiCompatibleTranslator(
    apiUrl: openRouterApiUrl,
    model: config.value<String>('model'),
    apiKey: config.secret('api_key') ?? '',
    temperature: config.value<double>('temperature'),
    maxTokens: config.value<int>('max_tokens'),
    timeout: Duration(seconds: config.value<int>('timeout')),
    info: openRouterInfo,
    resendMissing: config.value<bool>('resend_missing'),
  );
});

PluginEndpoint openRouterEndpoint(PluginConfig config) => const PluginEndpoint(Privacy.cloud, 'openrouter.ai');

KeyStatusQuery? openRouterKeyStatus(PluginConfig config) =>
    openRouterKeyQuery(openRouterApiUrl, config.secret('api_key') ?? '');

ModelCatalogQuery? openRouterModelCatalog(PluginConfig config) => openRouterModelQuery(openRouterApiUrl);
