/// What a service says about the user's API key: its limit, what is spent
/// and what is left (OpenRouter's `GET /api/v1/key`). Not in the original.
library;

/// When a key's spending limit starts again.
enum LimitReset { daily, weekly, monthly }

class KeyStatus {
  const KeyStatus({
    this.limit,
    this.remaining,
    this.used = 0,
    this.usedToday = 0,
    this.usedThisMonth = 0,
    this.limitReset,
    this.freeRequestsToday,
    this.freeRequestsLimit,
    this.freeRequestsLeft,
    this.label = '',
    this.freeTier,
  });

  /// The key's name as the service shows it (OpenRouter: the name given to
  /// it, or its start and end).
  final String label;

  /// No credits were ever bought for the account: free models allow fewer
  /// requests a day. Null when the service does not say.
  final bool? freeTier;

  /// Spending limit of the key in the service's credits (US dollars on
  /// OpenRouter); null when the key has no limit.
  final double? limit;

  /// What is left of [limit]; null when there is no limit.
  final double? remaining;

  /// Spent with this key: all time, today (UTC) and this month.
  final double used;
  final double usedToday;
  final double usedThisMonth;
  final LimitReset? limitReset;

  /// Requests to free models today and their daily limit, when the service
  /// counts them.
  final int? freeRequestsToday;
  final int? freeRequestsLimit;
  final int? freeRequestsLeft;
}

/// How to ask a service about the key of a configuration
/// ([PluginInfo.keyStatus]). Asking sends the key to [host]; the UI says so
/// and asks only when the user presses the button.
class KeyStatusQuery {
  const KeyStatusQuery({required this.host, required this.hasKey, required this.run});

  /// Where the key is sent.
  final String host;

  /// A key is saved; without one there is nothing to ask.
  final bool hasKey;

  /// Throws `TranslationException` (refused key, no connection, ...).
  final Future<KeyStatus> Function() run;
}

/// Decimals that show a sum of credits without hiding fractions of a cent:
/// 1 → 2 (`1.00`), 0.126 → 3, 0.9962 → 4, 0.00002 → 6.
int moneyDecimals(double v) {
  final tenThousandths = (v.abs() * 10000).round();
  if (v != 0 && tenThousandths == 0) return 6;
  if (tenThousandths % 100 == 0) return 2;
  if (tenThousandths % 10 == 0) return 3;
  return 4;
}
