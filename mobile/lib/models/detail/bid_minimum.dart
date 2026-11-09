/// Calculates the minimum integer bid directly from the API values.
/// Returns null if the source values cannot be parsed safely.
int? calculateBidMinimum({
  required Object? basePrice,
  required Object? currentLeaderAmount,
  required Object? minimumIncrement,
}) {
  final base = _number(basePrice);
  if (currentLeaderAmount == null) return base?.ceil();

  final leader = _number(currentLeaderAmount);
  final increment = _number(minimumIncrement);
  if (leader == null || increment == null) return null;
  final minimum = leader + increment;
  return minimum.isFinite ? minimum.ceil() : null;
}

num? _number(Object? value) {
  if (value is num) return value.isFinite ? value : null;
  if (value is String) {
    final parsed = num.tryParse(value);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
  return null;
}
