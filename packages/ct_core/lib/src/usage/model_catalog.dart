/// The models a service offers (OpenRouter's list), to pick one in the
/// settings instead of typing its id. Not in the original.
library;

/// One model of a service's list.
class CatalogModel {
  const CatalogModel({
    required this.id,
    this.name = '',
    this.description = '',
    this.contextLength,
    this.promptPrice,
    this.completionPrice,
    this.vision = false,
    this.created,
  });

  /// What goes into the model setting, e.g. `openai/gpt-4.1-mini`.
  final String id;
  final String name;
  final String description;

  /// The longest request with its answer, in tokens.
  final int? contextLength;

  /// US dollars per million tokens of the request and of the answer; null
  /// when the service does not say (a router picking the model itself).
  final double? promptPrice;
  final double? completionPrice;

  /// Takes pictures (the page image can go along).
  final bool vision;

  /// When the service added it.
  final DateTime? created;

  /// Costs nothing (limited requests a day instead).
  bool get free => id.endsWith(':free') || (promptPrice == 0 && completionPrice == 0);
}

/// How to get the list of models for a configuration
/// ([PluginInfo.modelCatalog]). Asking sends nothing of the user's (no key):
/// the UI still names [host] and asks only when the user presses the button.
class ModelCatalogQuery {
  const ModelCatalogQuery({required this.host, required this.settingKey, required this.run});

  /// Where the list comes from.
  final String host;

  /// The setting the picked model's id goes into.
  final String settingKey;

  /// Throws `TranslationException` (no connection, ...).
  final Future<List<CatalogModel>> Function() run;
}
