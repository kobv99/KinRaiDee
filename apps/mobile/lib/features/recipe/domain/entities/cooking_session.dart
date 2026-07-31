enum CookingSessionStatus { active, completed, abandoned }

class CookingSession {
  const CookingSession({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.startedAt,
    this.status = CookingSessionStatus.active,
    this.endedAt,
  });

  final String id;
  final String recipeId;
  final String recipeName;
  final int servings;
  final DateTime startedAt;
  final CookingSessionStatus status;
  final DateTime? endedAt;

  bool get isActive => status == CookingSessionStatus.active;

  Duration elapsedAt(DateTime now) {
    final end = endedAt ?? now;
    final elapsed = end.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  CookingSession copyWith({CookingSessionStatus? status, DateTime? endedAt}) {
    return CookingSession(
      id: id,
      recipeId: recipeId,
      recipeName: recipeName,
      servings: servings,
      startedAt: startedAt,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
